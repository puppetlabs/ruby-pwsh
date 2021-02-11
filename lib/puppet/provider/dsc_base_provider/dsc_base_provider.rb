# frozen_string_literal: true

require 'securerandom'
require 'ruby-pwsh'
require 'pathname'
require 'json'

class Puppet::Provider::DscBaseProvider
  # Initializes the provider, preparing the class variables which cache:
  # - the canonicalized resources across calls
  # - query results
  # - logon failures
  def initialize
    @@cached_canonicalized_resource ||= []
    @@cached_query_results ||= []
    @@logon_failures ||= []
    super
  end

  # Look through a cache to retrieve the hashes specified, if they have been cached.
  # Does so by seeing if each of the specified hashes is a subset of any of the hashes
  # in the cache, so {foo: 1, bar: 2} would return if {foo: 1} was the search hash.
  #
  # @param cache [Array] the class variable containing cached hashes to search through
  # @param hashes [Array] the list of hashes to search the cache for
  # @return [Array] an array containing the matching hashes for the search condition, if any
  def fetch_cached_hashes(cache, hashes)
    cache.reject do |item|
      matching_hash = hashes.select { |hash| (item.to_a - hash.to_a).empty? || (hash.to_a - item.to_a).empty? }
      matching_hash.empty?
    end.flatten
  end

  # Implements the canonicalize feature of the Resource API; this method is called first against any resources
  # defined in the manifest, then again to conform the results from a get call. The method attempts to retrieve
  # the DSC resource from the machine; if the resource is found, this method then compares the downcased values
  # of the two hashes, overwriting the manifest value with the discovered one if they are case insensitively
  # equivalent; this enables case insensitive but preserving behavior where a manifest declaration of a path as
  # "c:/foo/bar" if discovered on disk as "C:\Foo\Bar" will canonicalize to the latter and prevent any flapping.
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @param resources [Hash] the hash of the resource to canonicalize from either manifest or invocation
  # @return [Hash] returns a hash representing the current state of the object, if it exists
  def canonicalize(context, resources)
    canonicalized_resources = []
    resources.collect do |r|
      # During RSAPI refresh runs mandatory parameters are stripped and not available;
      # Instead of checking again and failing, search the cache for a namevar match.
      namevarized_r = r.select { |k, _v| namevar_attributes(context).include?(k) }
      if fetch_cached_hashes(@@cached_canonicalized_resource, [namevarized_r]).empty?
        canonicalized = invoke_get_method(context, r)
        if canonicalized.nil?
          canonicalized = r.dup
          @@cached_canonicalized_resource << r.dup
        else
          parameters = r.select { |name, _properties| parameter_attributes(context).include?(name) }
          canonicalized.merge!(parameters)
          canonicalized[:name] = r[:name]
          if r[:dsc_psdscrunascredential].nil?
            canonicalized.delete(:dsc_psdscrunascredential)
          else
            canonicalized[:dsc_psdscrunascredential] = r[:dsc_psdscrunascredential]
          end
          downcased_result = recursively_downcase(canonicalized)
          downcased_resource = recursively_downcase(r)
          downcased_result.each do |key, value|
            is_same = value.is_a?(Enumerable) & !downcased_resource[key].nil? ? downcased_resource[key].sort == value.sort : downcased_resource[key] == value
            canonicalized[key] = r[key] unless is_same
            canonicalized.delete(key) unless downcased_resource.keys.include?(key)
          end
          # Cache the actually canonicalized resource separately
          @@cached_canonicalized_resource << canonicalized.dup
        end
      else
        canonicalized = r
      end
      canonicalized_resources << canonicalized
    end
    context.debug("Canonicalized Resources: #{canonicalized_resources}")
    canonicalized_resources
  end

  # Attempts to retrieve an instance of the DSC resource, invoking the `Get` method and passing any
  # namevars as the Properties to Invoke-DscResource. The result object, if any, is compared to the
  # specified properties in the Puppet Resource to decide whether it needs to be created, updated,
  # deleted, or whether it is in the desired state.
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @param names [Hash] the hash of namevar properties and their values to use to get the resource
  # @return [Hash] returns a hash representing the current state of the object, if it exists
  def get(context, names = nil)
    # Relies on the get_simple_filter feature to pass the namevars
    # as an array containing the namevar parameters as a hash.
    # This hash is functionally the same as a should hash as
    # passed to the should_to_resource method.
    context.debug('Collecting data from the DSC Resource')

    # If the resource has already been queried, do not bother querying for it again
    cached_results = fetch_cached_hashes(@@cached_query_results, names)
    return cached_results unless cached_results.empty?

    if @@cached_canonicalized_resource.empty?
      mandatory_properties = {}
    else
      canonicalized_resource = @@cached_canonicalized_resource[0].dup
      mandatory_properties = canonicalized_resource.select do |attribute, _value|
        (mandatory_get_attributes(context) - namevar_attributes(context)).include?(attribute)
      end
      # If dsc_psdscrunascredential was specified, re-add it here.
      mandatory_properties[:dsc_psdscrunascredential] = canonicalized_resource[:dsc_psdscrunascredential] if canonicalized_resource.keys.include?(:dsc_psdscrunascredential)
    end
    names.collect do |name|
      name = { name: name } if name.is_a? String
      invoke_get_method(context, name.merge(mandatory_properties))
    end
  end

  # Determines whether a resource is ensurable and which message to write (create, update, or delete),
  # then passes the appropriate values along to the various sub-methods which themselves call the Set
  # method of Invoke-DscResource. Implementation borrowed directly from the Resource API Simple Provider
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @param changes [Hash] the hash of whose key is the name_hash and value is the is and should hashes
  def set(context, changes)
    changes.each do |name, change|
      is = change.key?(:is) ? change[:is] : (get(context, [name]) || []).find { |r| r[:name] == name }
      context.type.check_schema(is) unless change.key?(:is)

      should = change[:should]

      name_hash = if context.type.namevars.length > 1
                    # pass a name_hash containing the values of all namevars
                    name_hash = {}
                    context.type.namevars.each do |namevar|
                      name_hash[namevar] = change[:should][namevar]
                    end
                    name_hash
                  else
                    name
                  end

      # for compatibility sake, we use dsc_ensure instead of ensure, so context.type.ensurable? does not work
      if context.type.attributes.key?(:dsc_ensure)
        is = create_absent(:name, name) if is.nil?
        should = create_absent(:name, name) if should.nil?

        # HACK: If the DSC Resource is ensurable but doesn't report a default value
        # for ensure, we assume it to be `Present` - this is the most common pattern.
        should_ensure = should[:dsc_ensure].nil? ? 'Present' : should[:dsc_ensure].to_s
        # HACK: Sometimes dsc_ensure is removed???? If it's gone, pretend it's absent??
        is_ensure = is[:dsc_ensure].nil? ? 'Absent' : is[:dsc_ensure].to_s

        if is_ensure == 'Absent' && should_ensure == 'Present'
          context.creating(name) do
            create(context, name_hash, should)
          end
        elsif is_ensure == 'Present' && should_ensure == 'Present'
          context.updating(name) do
            update(context, name_hash, should)
          end
        elsif is_ensure == 'Present' && should_ensure == 'Absent'
          context.deleting(name) do
            delete(context, name_hash)
          end
        else
          # In this case we are not sure if the resource is being created/updated/removed
          # as with ensure "latest" or a specific version number, so default to update.
          context.updating(name) do
            update(context, name_hash, should)
          end
        end
      else
        context.updating(name) do
          update(context, name_hash, should)
        end
      end
    end
  end

  # Creates a hash with the name / name_hash and sets dsc_ensure to absent for comparison
  # purposes; this handles cases where the resource isn't found on the node.
  #
  # @param namevar [Object] the name of the variable being used for the resource name
  # @param title [Hash] the hash of namevar properties and their values
  # @return [Hash] returns a hash representing the absent state of the resource
  def create_absent(namevar, title)
    result = if title.is_a? Hash
               title.dup
             else
               { namevar => title }
             end
    result[:dsc_ensure] = 'Absent'
    result
  end

  # Attempts to set an instance of the DSC resource, invoking the `Set` method and thinly wrapping
  # the `invoke_set_method` method; whether this method, `update`, or `delete` is called is entirely
  # up to the Resource API based on the results
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @param name [String] the name of the resource being created
  # @return [Hash] returns a hash indicating whether or not the resource is in the desired state, whether or not it requires a reboot, and any error messages captured.
  def create(context, name, should)
    context.debug("Creating '#{name}' with #{should.inspect}")
    invoke_set_method(context, name, should)
  end

  # Attempts to set an instance of the DSC resource, invoking the `Set` method and thinly wrapping
  # the `invoke_set_method` method; whether this method, `create`, or `delete` is called is entirely
  # up to the Resource API based on the results
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @param name [String] the name of the resource being created
  # @return [Hash] returns a hash indicating whether or not the resource is in the desired state, whether or not it requires a reboot, and any error messages captured.
  def update(context, name, should)
    context.debug("Updating '#{name}' with #{should.inspect}")
    invoke_set_method(context, name, should)
  end

  # Attempts to set an instance of the DSC resource, invoking the `Set` method and thinly wrapping
  # the `invoke_set_method` method; whether this method, `create`, or `update` is called is entirely
  # up to the Resource API based on the results
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @param name [String] the name of the resource being created
  # @return [Hash] returns a hash indicating whether or not the resource is in the desired state, whether or not it requires a reboot, and any error messages captured.
  def delete(context, name)
    context.debug("Deleting '#{name}'")
    invoke_set_method(context, name, name.merge({ dsc_ensure: 'Absent' }))
  end

  # Invokes the `Get` method, passing the name_hash as the properties to use with `Invoke-DscResource`
  # The PowerShell script returns a JSON representation of the DSC Resource's CIM Instance munged as
  # best it can be for Ruby. Once that JSON is parsed into a hash this method further munges it to
  # fit the expected property definitions. Finally, it returns the object for the Resource API to
  # compare against and determine what future actions, if any, are needed.
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @param name_hash [Hash] the hash of namevars to be passed as properties to `Invoke-DscResource`
  # @return [Hash] returns a hash representing the DSC resource munged to the representation the Puppet Type expects
  def invoke_get_method(context, name_hash)
    context.debug("retrieving #{name_hash.inspect}")

    # Do not bother running if the logon credentials won't work
    return name_hash if !name_hash[:dsc_psdscrunascredential].nil? && logon_failed_already?(name_hash[:dsc_psdscrunascredential])

    query_props = name_hash.select { |k, v| mandatory_get_attributes(context).include?(k) || (k == :dsc_psdscrunascredential && !v.nil?) }
    resource = should_to_resource(query_props, context, 'get')
    script_content = ps_script_content(resource)
    context.debug("Script:\n #{redact_secrets(script_content)}")
    output = ps_manager.execute(script_content)[:stdout]
    context.err('Nothing returned') if output.nil?

    data = JSON.parse(output)
    context.debug("raw data received: #{data.inspect}")
    error = data['errormessage']
    unless error.nil?
      # NB: We should have a way to stop processing this resource *now* without blowing up the whole Puppet run
      # Raising an error stops processing but blows things up while context.err alerts but continues to process
      if error =~ /Logon failure: the user has not been granted the requested logon type at this computer/
        logon_error = "PSDscRunAsCredential account specified (#{name_hash[:dsc_psdscrunascredential]['user']}) does not have appropriate logon rights; are they an administrator?"
        name_hash[:name].nil? ? context.err(logon_error) : context.err(name_hash[:name], logon_error)
        @@logon_failures << name_hash[:dsc_psdscrunascredential].dup
        # This is a hack to handle the query cache to prevent a second lookup
        @@cached_query_results << name_hash # if fetch_cached_hashes(@@cached_query_results, [data]).empty?
      else
        context.err(error)
      end
      # Either way, something went wrong and we didn't get back a good result, so return nil
      return nil
    end
    # DSC gives back information we don't care about; filter down to only
    # those properties exposed in the type definition.
    valid_attributes = context.type.attributes.keys.collect(&:to_s)
    parameters = context.type.attributes.select { |_name, properties| [properties[:behaviour]].collect.include?(:parameter) }.keys.collect(&:to_s)
    data.select! { |key, _value| valid_attributes.include?("dsc_#{key.downcase}") }
    data.reject! { |key, _value| parameters.include?("dsc_#{key.downcase}") }
    # Canonicalize the results to match the type definition representation;
    # failure to do so will prevent the resource_api from comparing the result
    # to the should hash retrieved from the resource definition in the manifest.
    data.keys.each do |key| # rubocop:disable Style/HashEachMethods
      type_key = "dsc_#{key.downcase}".to_sym
      data[type_key] = data.delete(key)
      camelcase_hash_keys!(data[type_key]) if data[type_key].is_a?(Enumerable)
      # Convert DateTime back to appropriate type
      data[type_key] = Puppet::Pops::Time::Timestamp.parse(data[type_key]) if context.type.attributes[type_key][:mof_type] =~ /DateTime/i
      # PowerShell does not distinguish between a return of empty array/string
      #  and null but Puppet does; revert to those values if specified.
      if data[type_key].nil? && query_props.keys.include?(type_key) && query_props[type_key].is_a?(Array)
        data[type_key] = query_props[type_key].empty? ? query_props[type_key] : []
      end
    end
    # If a resource is found, it's present, so refill this Puppet-only key
    data.merge!({ name: name_hash[:name] })

    # Have to check for this to avoid a weird canonicalization warning
    # The Resource API calls canonicalize against the current state which
    # will lead to dsc_ensure being set to absent in the name_hash even if
    # it was set to present in the manifest
    name_hash_has_nil_keys = name_hash.select { |_k, v| v.nil? }.count.positive?
    # We want to throw away all of the empty keys if and only if the manifest
    # declaration is for an absent resource and the resource is actually absent
    data.reject! { |_k, v| v.nil? } if data[:dsc_ensure] == 'Absent' && name_hash[:dsc_ensure] == 'Absent' && !name_hash_has_nil_keys

    # Cache the query to prevent a second lookup
    @@cached_query_results << data.dup if fetch_cached_hashes(@@cached_query_results, [data]).empty?
    context.debug("Returned to Puppet as #{data}")
    data
  end

  # Invokes the `Set` method, passing the should hash as the properties to use with `Invoke-DscResource`
  # The PowerShell script returns a JSON hash with key-value pairs indicating whether or not the resource
  # is in the desired state, whether or not it requires a reboot, and any error messages captured.
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @param should [Hash] the desired state represented definition to pass as properties to Invoke-DscResource
  # @return [Hash] returns a hash indicating whether or not the resource is in the desired state, whether or not it requires a reboot, and any error messages captured.
  def invoke_set_method(context, name, should)
    context.debug("Invoking Set Method for '#{name}' with #{should.inspect}")

    # Do not bother running if the logon credentials won't work
    return nil if !should[:dsc_psdscrunascredential].nil? && logon_failed_already?(should[:dsc_psdscrunascredential])

    apply_props = should.select { |k, _v| k.to_s =~ /^dsc_/ }
    resource = should_to_resource(apply_props, context, 'set')
    script_content = ps_script_content(resource)
    context.debug("Script:\n #{redact_secrets(script_content)}")

    output = ps_manager.execute(script_content)[:stdout]
    context.err('Nothing returned') if output.nil?

    data = JSON.parse(output)
    context.debug(data)

    context.err(data['errormessage']) unless data['errormessage'].empty?
    # TODO: Implement this functionality for notifying a DSC reboot?
    # notify_reboot_pending if data['rebootrequired'] == true
    data
  end

  # Converts a Puppet resource hash into a hash with the information needed to call Invoke-DscResource,
  # including the desired state, the path to the PowerShell module containing the resources, the invoke
  # method, and metadata about the DSC Resource and Puppet Type.
  #
  # @param should [Hash] A hash representing the desired state of the DSC resource as defined in Puppet
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @param dsc_invoke_method [String] the method to pass to Invoke-DscResource: get, set, or test
  # @return [Hash] a hash with the information needed to run `Invoke-DscResource`
  def should_to_resource(should, context, dsc_invoke_method)
    resource = {}
    resource[:parameters] = {}
    %i[name dscmeta_resource_friendly_name dscmeta_resource_name dscmeta_module_name dscmeta_module_version].each do |k|
      resource[k] = context.type.definition[k]
    end
    should.each do |k, v|
      # PSDscRunAsCredential is considered a namevar and will always be passed, even if nil
      # To prevent flapping during runs, remove it from the resource definition unless specified
      next if k == :dsc_psdscrunascredential && v.nil?

      resource[:parameters][k] = {}
      resource[:parameters][k][:value] = v
      %i[mof_type mof_is_embedded].each do |ky|
        resource[:parameters][k][ky] = context.type.definition[:attributes][k][ky]
      end
    end
    resource[:dsc_invoke_method] = dsc_invoke_method

    # Because Puppet adds all of the modules to the LOAD_PATH we can be sure that the appropriate module lives here during an apply;
    # PROBLEM: This currently uses the downcased name, we need to capture the module name in the metadata I think.
    # During a Puppet agent run, the code lives in the cache so we can use the file expansion to discover the correct folder.
    # This handles setting the vendored_modules_path to include the puppet module name; we now add the puppet module name into the
    # path to allow multiple modules to with shared dsc_resources to be installed side by side
    # The old vendored_modules_path: puppet_x/dsc_resources
    # The new vendored_modules_path: puppet_x/<module_name>/dsc_resources
    root_module_path = $LOAD_PATH.select { |path| path.match?(%r{#{puppetize_name(resource[:dscmeta_module_name])}/lib}) }.first
    resource[:vendored_modules_path] = if root_module_path.nil?
                                         File.expand_path(Pathname.new(__FILE__).dirname + '../../../' + "puppet_x/#{puppetize_name(resource[:dscmeta_module_name])}/dsc_resources") # rubocop:disable Style/StringConcatenation
                                       else
                                         File.expand_path("#{root_module_path}/puppet_x/#{puppetize_name(resource[:dscmeta_module_name])}/dsc_resources")
                                       end

    # Check for the old vendored_modules_path second - if there is a mix of modules with the old and new pathing,
    # checking for this first will always work and so the more specific search will never run.
    unless File.exist? resource[:vendored_modules_path]
      resource[:vendored_modules_path] = if root_module_path.nil?
                                           File.expand_path(Pathname.new(__FILE__).dirname + '../../../' + 'puppet_x/dsc_resources') # rubocop:disable Style/StringConcatenation
                                         else
                                           File.expand_path("#{root_module_path}/puppet_x/dsc_resources")
                                         end
    end

    # A warning is thrown if the something went wrong and the file was not created
    raise "Unable to find expected vendored DSC Resource #{resource[:vendored_modules_path]}" unless File.exist? resource[:vendored_modules_path]

    resource[:attributes] = nil

    context.debug("should_to_resource: #{resource.inspect}")
    resource
  end

  # Return a String containing a puppetized name. A puppetized name is a string that only
  # includes lowercase letters, digits, underscores and cannot start with a digit.
  #
  # @return [String] with a puppeized module name
  def puppetize_name(name)
    # Puppet module names must be lower case
    name = name.downcase
    # Puppet module names must only include lowercase letters, digits and underscores
    name = name.gsub(/[^a-z0-9_]/, '_')
    # Puppet module names must not start with a number so if it does, append the letter 'a' to the name. Eg: '7zip' becomes 'a7zip'
    name = name.match?(/^\d/) ? "a#{name}" : name # rubocop:disable Lint/UselessAssignment
  end

  # Return a UUID with the dashes turned into underscores to enable the specifying of guaranteed-unique
  # variables in the PowerShell script.
  #
  # @return [String] a uuid with underscores instead of dashes.
  def random_variable_name
    # PowerShell variables can't include dashes
    SecureRandom.uuid.gsub('-', '_')
  end

  # Return a Hash containing all of the variables defined for instantiation as well as the Ruby hash for their
  # properties so they can be matched and replaced as needed.
  #
  # @return [Hash] containing all instantiated variables and the properties that they define
  def instantiated_variables
    @@instantiated_variables ||= {}
  end

  # Clear the instantiated variables hash to be ready for the next run
  def clear_instantiated_variables!
    @@instantiated_variables = {}
  end

  # Return true if the specified credential hash has already failed to execute a DSC resource due to
  # a logon error, as when the account is not an administrator on the machine; otherwise returns false.
  #
  # @param [Hash] a credential hash with a user and password keys where the password is a sensitive string
  # @return [Bool] true if the credential_hash has already failed logon, false otherwise
  def logon_failed_already?(credential_hash)
    @@logon_failures.any? do  |failure_hash|
      failure_hash['user'] == credential_hash['user'] && failure_hash['password'].unwrap == credential_hash['password'].unwrap
    end
  end

  # Recursively transforms any enumerable, camelCasing any hash keys it finds
  #
  # @param enumerable [Enumerable] a string, array, hash, or other object to attempt to recursively downcase
  # @return [Enumerable] returns the input object with hash keys recursively camelCased
  def camelcase_hash_keys!(enumerable)
    if enumerable.is_a?(Hash)
      enumerable.keys.each do |key| # rubocop:disable Style/HashEachMethods
        name = key.dup
        name[0] = name[0].downcase
        enumerable[name] = enumerable.delete(key)
        camelcase_hash_keys!(enumerable[name]) if enumerable[name].is_a?(Enumerable)
      end
    else
      enumerable.each { |item| camelcase_hash_keys!(item) if item.is_a?(Enumerable) }
    end
  end

  # Recursively transforms any object, downcasing it to enable case insensitive comparisons
  #
  # @param object [Object] a string, array, hash, or other object to attempt to recursively downcase
  # @return [Object] returns the input object recursively downcased
  def recursively_downcase(object)
    case object
    when String
      object.downcase
    when Array
      object.map { |item| recursively_downcase(item) }
    when Hash
      transformed = {}
      object.transform_keys(&:downcase).each do |key, value|
        transformed[key] = recursively_downcase(value)
      end
      transformed
    else
      object
    end
  end

  # Parses the DSC resource type definition to retrieve the names of any attributes which are specified as mandatory for get operations
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @return [Array] returns an array of attribute names as symbols which are mandatory for get operations
  def mandatory_get_attributes(context)
    context.type.attributes.select { |_attribute, properties| properties[:mandatory_for_get] }.keys
  end

  # Parses the DSC resource type definition to retrieve the names of any attributes which are specified as mandatory for set operations
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @return [Array] returns an array of attribute names as symbols which are mandatory for set operations
  def mandatory_set_attributes(context)
    context.type.attributes.select { |_attribute, properties| properties[:mandatory_for_set] }.keys
  end

  # Parses the DSC resource type definition to retrieve the names of any attributes which are specified as namevars
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @return [Array] returns an array of attribute names as symbols which are namevars
  def namevar_attributes(context)
    context.type.attributes.select { |_attribute, properties| properties[:behaviour] == :namevar }.keys
  end

  # Parses the DSC resource type definition to retrieve the names of any attributes which are specified as parameters
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @return [Array] returns an array of attribute names as symbols which are parameters
  def parameter_attributes(context)
    context.type.attributes.select { |_name, properties| properties[:behaviour] == :parameter }.keys
  end

  # Look through a fully formatted string, replacing all instances where a value matches the formatted properties
  # of an instantiated variable with references to the variable instead. This allows us to pass complex and nested
  # CIM instances to the Invoke-DscResource parameter hash without constructing them *in* the hash.
  #
  # @param string [String] the string of text to search through for places an instantiated variable can be referenced
  # @return [String] the string with references to instantiated variables instead of their properties
  def interpolate_variables(string)
    modified_string = string
    # Always replace later-created variables first as they sometimes were built from earlier ones
    instantiated_variables.reverse_each do |variable_name, ruby_definition|
      modified_string = modified_string.gsub(format(ruby_definition), "$#{variable_name}")
    end
    modified_string
  end

  # Parses a resource definition (as from `should_to_resource`) for any properties which are PowerShell
  # Credentials. As these values need to be serialized into PSCredential objects, return an array of
  # PowerShell lines, each of which instantiates a variable which holds the value as a PSCredential.
  # These credential variables can then be simply assigned in the parameter hash where needed.
  #
  # @param resource [Hash] a hash with the information needed to run `Invoke-DscResource`
  # @return [String] An array of lines of PowerShell to instantiate PSCredentialObjects and store them in variables
  def prepare_credentials(resource)
    credentials_block = []
    resource[:parameters].each do |_property_name, property_hash|
      next unless property_hash[:mof_type] == 'PSCredential'
      next if property_hash[:value].nil?

      variable_name = random_variable_name
      credential_hash = {
        'user' => property_hash[:value]['user'],
        'password' => escape_quotes(property_hash[:value]['password'].unwrap)
      }
      credentials_block << format_pscredential(variable_name, credential_hash)
      instantiated_variables.merge!(variable_name => credential_hash)
    end
    credentials_block.join("\n")
    credentials_block == [] ? '' : credentials_block
  end

  # Write a line of PowerShell which creates a PSCredential object and assigns it to a variable
  #
  # @param variable_name [String] the name of the Variable to assign the PSCredential object to
  # @param credential_hash [Hash] the Properties which define the PSCredential Object
  # @return [String] A line of PowerShell which defines the PSCredential object and stores it to a variable
  def format_pscredential(variable_name, credential_hash)
    "$#{variable_name} = New-PSCredential -User #{credential_hash['user']} -Password '#{credential_hash['password']}' # PuppetSensitive"
  end

  # Parses a resource definition (as from `should_to_resource`) for any properties which are CIM instances
  # whether at the top level or nested inside of other CIM instances, and, where they are discovered, adds
  # those objects to the instantiated_variables hash as well as returning a line of PowerShell code which
  # will create the CIM object and store it in a variable. This then allows the CIM instances to be assigned
  # by variable reference.
  #
  # @param resource [Hash] a hash with the information needed to run `Invoke-DscResource`
  # @return [String] An array of lines of PowerShell to instantiate CIM Instances and store them in variables
  def prepare_cim_instances(resource)
    cim_instances_block = []
    resource[:parameters].each do |_property_name, property_hash|
      next unless property_hash[:mof_is_embedded]
      next if property_hash[:mof_type] == 'PSCredential' # Credentials are handled separately

      # strip dsc_ from the beginning of the property name declaration
      # name = property_name.to_s.gsub(/^dsc_/, '').to_sym
      # Process nested CIM instances first as those neeed to be passed to higher-order
      # instances and must therefore be declared before they must be referenced
      cim_instance_hashes = nested_cim_instances(property_hash[:value]).flatten.reject(&:nil?)
      # Sometimes the instances are an empty array
      unless cim_instance_hashes.count.zero?
        cim_instance_hashes.each do |instance|
          variable_name = random_variable_name
          class_name = instance['cim_instance_type']
          properties = instance.reject { |k, _v| k == 'cim_instance_type' }
          cim_instances_block << format_ciminstance(variable_name, class_name, properties)
          instantiated_variables.merge!(variable_name => instance)
        end
      end
      # We have to handle arrays of CIM instances slightly differently
      if property_hash[:mof_type] =~ /\[\]$/
        class_name = property_hash[:mof_type].gsub('[]', '')
        property_hash[:value].each do |hash|
          variable_name = random_variable_name
          cim_instances_block << format_ciminstance(variable_name, class_name, hash)
          instantiated_variables.merge!(variable_name => hash)
        end
      else
        variable_name = random_variable_name
        class_name = property_hash[:mof_type]
        cim_instances_block << format_ciminstance(variable_name, class_name, property_hash[:value])
        instantiated_variables.merge!(variable_name => property_hash[:value])
      end
    end
    cim_instances_block == [] ? '' : cim_instances_block.join("\n")
  end

  # Recursively search for and return CIM instances nested in an enumerable
  #
  # @param enumerable [Enumerable] a hash or array which may contain CIM Instances
  # @return [Hash] every discovered hash which does define a CIM Instance
  def nested_cim_instances(enumerable)
    enumerable.collect do |key, value|
      if key.is_a?(Hash) && key.key?('cim_instance_type')
        key
        # TODO: Are there any cim instancees 3 levels deep, or only 2?
        # if so, we should *also* keep searching and processing...
      elsif key.is_a?(Enumerable)
        nested_cim_instances(key)
      elsif value.is_a?(Enumerable)
        nested_cim_instances(value)
      end
    end
  end

  # Write a line of PowerShell which creates a CIM Instance and assigns it to a variable
  #
  # @param variable_name [String] the name of the Variable to assign the CIM Instance to
  # @param class_name [String] the CIM Class to instantiate
  # @param property_hash [Hash] the Properties which define the CIM Instance
  # @return [String] A line of PowerShell which defines the CIM Instance and stores it to a variable
  def format_ciminstance(variable_name, class_name, property_hash)
    definition = "$#{variable_name} = New-CimInstance -ClientOnly -ClassName '#{class_name}' -Property #{format(property_hash)}"
    # AWFUL HACK to make New-CimInstance happy ; it can't parse an array unless it's an array of Cim Instances
    # definition = definition.gsub("@(@{'cim_instance_type'","[CimInstance[]]@(@{'cim_instance_type'")
    # EVEN WORSE HACK - this one we can't even be sure it's a cim instance...
    # but I don't _think_ anything but nested cim instances show up as hashes inside an array
    definition = definition.gsub('@(@{', '[CimInstance[]]@(@{')
    interpolate_variables(definition)
  end

  # Munge a resource definition (as from `should_to_resource`) into valid PowerShell which represents
  # the `InvokeParams` hash which will be splatted to `Invoke-DscResource`, interpolating all previously
  # defined variables into the hash.
  #
  # @param resource [Hash] a hash with the information needed to run `Invoke-DscResource`
  # @return [String] A string representing the PowerShell definition of the InvokeParams hash
  def invoke_params(resource)
    params = {
      Name: resource[:dscmeta_resource_friendly_name],
      Method: resource[:dsc_invoke_method],
      Property: {}
    }
    if resource.key?(:dscmeta_module_version)
      params[:ModuleName] = {}
      params[:ModuleName][:ModuleName] = "#{resource[:vendored_modules_path]}/#{resource[:dscmeta_module_name]}/#{resource[:dscmeta_module_name]}.psd1"
      params[:ModuleName][:RequiredVersion] = resource[:dscmeta_module_version]
    else
      params[:ModuleName] = resource[:dscmeta_module_name]
    end
    resource[:parameters].each do |property_name, property_hash|
      # strip dsc_ from the beginning of the property name declaration
      name = property_name.to_s.gsub(/^dsc_/, '').to_sym
      params[:Property][name] = case property_hash[:mof_type]
                                when 'PSCredential'
                                  # format can't unwrap Sensitive strings nested in arbitrary hashes/etc, so make
                                  # the Credential hash interpolable as it will be replaced by a variable reference.
                                  {
                                    'user' => property_hash[:value]['user'],
                                    'password' => escape_quotes(property_hash[:value]['password'].unwrap)
                                  }
                                when 'DateTime'
                                  # These have to be handled specifically because they rely on the *Puppet* DateTime,
                                  # not a generic ruby data type (and so can't go in the shared util in ruby-pwsh)
                                  "[DateTime]#{property_hash[:value].format('%FT%T%z')}"
                                else
                                  property_hash[:value]
                                end
    end
    params_block = interpolate_variables("$InvokeParams = #{format(params)}")
    # Move the Apostrophe for DateTime declarations
    params_block = params_block.gsub("'[DateTime]", "[DateTime]'")
    # HACK: Handle intentionally empty arrays - need to strongly type them because
    # CIM instances do not do a consistent job of casting an empty array properly.
    empty_array_parameters = resource[:parameters].select { |_k, v| v[:value].is_a?(Array) && v[:value].empty? }
    empty_array_parameters.each do |name, properties|
      param_block_name = name.to_s.gsub(/^dsc_/, '')
      params_block = params_block.gsub("#{param_block_name} = @()", "#{param_block_name} = [#{properties[:mof_type]}]@()")
    end
    # HACK: make CIM instances work:
    resource[:parameters].select { |_key, hash| hash[:mof_is_embedded] && hash[:mof_type] =~ /\[\]/ }.each do |_property_name, property_hash|
      formatted_property_hash = interpolate_variables(format(property_hash[:value]))
      params_block = params_block.gsub(formatted_property_hash, "[CimInstance[]]#{formatted_property_hash}")
    end
    params_block
  end

  # Given a resource definition (as from `should_to_resource`), return a PowerShell script which has
  # all of the appropriate function and variable definitions, which will call Invoke-DscResource, and
  # will correct munge the results for returning to Puppet as a JSON object.
  #
  # @param resource [Hash] a hash with the information needed to run `Invoke-DscResource`
  # @return [String] A string representing the PowerShell script which will invoke the DSC Resource.
  def ps_script_content(resource)
    template_path = File.expand_path('../', __FILE__)
    # Defines the helper functions
    functions     = File.new("#{template_path}/invoke_dsc_resource_functions.ps1").read
    # Defines the response hash and the runtime settings
    preamble      = File.new("#{template_path}/invoke_dsc_resource_preamble.ps1").read
    # The postscript defines the invocation error and result handling; expects `$InvokeParams` to be defined
    postscript    = File.new("#{template_path}/invoke_dsc_resource_postscript.ps1").read
    # The blocks define the variables to define for the postscript.
    credential_block = prepare_credentials(resource)
    cim_instances_block = prepare_cim_instances(resource)
    parameters_block = invoke_params(resource)
    # clean them out of the temporary cache now that they're not needed; failure to do so can goof up future executions in this run
    clear_instantiated_variables!

    [functions, preamble, credential_block, cim_instances_block, parameters_block, postscript].join("\n")
  end

  # Convert a Puppet/Ruby value into a PowerShell representation. Requires some slight additional
  # munging over what is provided in the ruby-pwsh library, as it does not handle unwrapping Sensitive
  # data types or interpolating Credentials.
  #
  # @param value [Object] The object to format into valid PowerShell
  # @return [String] A string representation of the input value as valid PowerShell
  def format(value)
    Pwsh::Util.format_powershell_value(value)
  rescue RuntimeError => e
    raise unless e.message =~ /Sensitive \[value redacted\]/

    string = Pwsh::Util.format_powershell_value(unwrap(value))
    string.gsub(/#PuppetSensitive'}/, "'} # PuppetSensitive")
  end

  # Unwrap sensitive strings for formatting, even inside an enumerable, appending '#PuppetSensitive'
  # to the end of the string in preparation for gsub cleanup.
  #
  # @param value [Object] The object to unwrap sensitive data inside of
  # @return [Object] The object with any sensitive strings unwrapped and annotated
  def unwrap(value)
    case value
    when Puppet::Pops::Types::PSensitiveType::Sensitive
      "#{value.unwrap}#PuppetSensitive"
    when Hash
      unwrapped = {}
      value.each do |k, v|
        unwrapped[k] = unwrap(v)
      end
      unwrapped
    when Array
      unwrapped = []
      value.each do |v|
        unwrapped << unwrap(v)
      end
      unwrapped
    else
      value
    end
  end

  # Escape any nested single quotes in a Sensitive string
  #
  # @param text [String] the text to escape
  # @return [String] the escaped text
  def escape_quotes(text)
    text.gsub("'", "''")
  end

  # While Puppet is aware of Sensitive data types, the PowerShell script is not
  # and so for debugging purposes must be redacted before being sent to debug
  # output but must *not* be redacted when sent to the PowerShell code manager.
  #
  # @param text [String] the text to redact
  # @return [String] the redacted text
  def redact_secrets(text)
    # Every secret unwrapped in this module will unwrap as "'secret' # PuppetSensitive" and, currently,
    # no known resources specify a SecureString instead of a PSCredential object. We therefore only
    # need to redact strings which look like password declarations.
    modified_text = text.gsub(/(?<=-Password )'.+' # PuppetSensitive/, "'#<Sensitive [value redacted]>'")
    if modified_text =~ /'.+' # PuppetSensitive/
      # Something has gone wrong, error loudly?
    else
      modified_text
    end
  end

  # Instantiate a PowerShell manager via the ruby-pwsh library and use it to invoke PowerShell.
  # Definiing it here allows re-use of a single instance instead of continually instantiating and
  # tearing a new instance down for every call.
  def ps_manager
    debug_output = Puppet::Util::Log.level == :debug
    # TODO: Allow you to specify an alternate path, either to pwsh generally or a specific pwsh path.
    Pwsh::Manager.instance(Pwsh::Manager.powershell_path, Pwsh::Manager.powershell_args, debug: debug_output)
  end
end
