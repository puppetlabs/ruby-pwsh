# Contributing to ruby-pwsh

So you want to contribute to the ruby-pwsh gem: Great! Below are some instructions to get you started doing
that very thing while setting expectations around code quality as well as a few tips for making the
process as easy as possible.

## Table of Contents

1. [Getting Started](#getting-started)
1. [Commit Checklist](#commit-checklist)
1. [Submission](#submission)
1. [More about commits](#more-about-commits)
1. [Testing](#testing)
    - [Running Tests](#running-tests)
    - [Writing Tests](#writing-tests)
1. [Get Help](#get-help)

## Getting Started

- Fork the module repository on GitHub and clone to your workspace
- Make your changes!

## Commit Checklist

### The Basics

- [x] my commit is a single logical unit of work
- [x] I have checked for unnecessary whitespace with "git diff --check"
- [x] my commit does not include commented out code or unneeded files

### The Content

- [x] my commit includes tests for the bug I fixed or feature I added
- [x] my commit includes appropriate documentation changes if it is introducing a new feature or changing existing functionality
- [x] my code passes existing test suites

### The Commit Message

- [x] the first line of my commit message includes:
  - [x] an issue number (if applicable), e.g. "(GH-xxxx) This is the first line"
  - [x] a short description (50 characters is the soft limit, excluding issue number(s))
- [x] the body of my commit message:
  - [x] is meaningful
  - [x] uses the imperative, present tense: "change", not "changed" or "changes"
  - [x] includes motivation for the change, and contrasts its implementation with the previous behavior

## Submission

### Pre-requisites

- Make sure you have a [GitHub account](https://github.com/join)
- [Create an issue](https://github.com/puppetlabs/ruby-pwsh/issues/new/choose), or [watch the issue](https://github.com/puppetlabs/ruby-pwsh/issues) you are patching for.

### Push and PR

- Push your changes to your fork
- [Open a Pull Request](https://help.github.com/articles/creating-a-pull-request-from-a-fork/) against the repository in the puppetlabs organization

## More about commits

1.  Make separate commits for logically separate changes.

    Please break your commits down into logically consistent units which include new or changed tests relevant to the rest of the change.
    The goal of doing this is to make the diff easier to read for whoever is reviewing your code.
    In general, the easier your diff is to read, the more likely someone will be happy to review it and get it into the code base.

    If you are going to refactor a piece of code, please do so as a separate commit from your feature or bug fix changes.

    We also really appreciate changes that include tests to make sure the bug is not re-introduced, and that the feature is not accidentally broken.

    Describe the technical detail of the change(s).
    If your description starts to get too long, that is a good sign that you probably need to split up your commit into more finely grained pieces.

    Commits which plainly describe the things which help reviewers check the patch and future developers understand the code are much more likely to be merged in with a minimum of bike-shedding or requested changes.
    Ideally, the commit message would include information, and be in a form suitable for inclusion in the release notes for the version of Puppet that includes them.

    Please also check that you are not introducing any trailing whitespace or other "whitespace errors".
    You can do this by running `git diff --check` on your changes before you commit.

2.  Sending your patches

    To submit your changes via a GitHub pull request, we _highly_ recommend that you have them on a topic branch, instead of directly on "main".
    It makes things much easier to keep track of, especially if you decide to work on another thing before your first change is merged in.

    GitHub has some pretty good [general documentation](http://help.github.com/) on using their site.
    They also have documentation on [creating pull requests](https://help.github.com/articles/creating-a-pull-request-from-a-fork/).

    In general, after pushing your topic branch up to your repository on GitHub, you can switch to the branch in the GitHub UI and click "Pull Request" towards the top of the page in order to open a pull request.

3.  Update the related GitHub issue.

    If there is a GitHub issue associated with the change you submitted, then you should update the issue to include the location of your branch, along with any other commentary you may wish to make.

# Testing

## Getting Started

Our Puppet modules provide [`Gemfile`](./Gemfile)s, which can tell a Ruby package manager such as [bundler](http://bundler.io/) what Ruby packages,
or Gems, are required to build, develop, and test this software.

Please make sure you have [bundler installed](http://bundler.io/#getting-started) on your system, and then use it to
install all dependencies needed for this project in the project root by running

```shell
# Unless you're doing a release, you don't need the puppet gem group
% bundle install --path .bundle/gems --without puppet
Fetching gem metadata from https://rubygems.org/........
Fetching gem metadata from https://rubygems.org/..
Using rake (10.1.0)
Using builder (3.2.2)
-- 8><-- many more --><8 --
Your bundle is complete!
Use `bundle show [gemname]` to see where a bundled gem is installed.
```

NOTE: some systems may require you to run this command with sudo.

If you already have those gems installed, make sure they are up-to-date:

```shell
% bundle update
```

## Running Tests

With all dependencies in place and up-to-date, run the tests:

### Unit Tests

```shell
% bundle exec rake spec
```

This executes all the [rspec tests](https://rspec.info/) in the `spec` directory.

## If you have commit access to the repository

Even if you have commit access to the repository, you still need to go through the process above, and have someone else review and merge
in your changes.
The rule is that **all changes must be reviewed by a project developer that did not write the code to ensure that all changes go through a code review process.**

The record of someone performing the merge is the record that they performed the code review.
Again, this should be someone other than the author of the topic branch.

## Get Help

### On the web

- [General GitHub documentation](http://help.github.com/)
- [GitHub pull request documentation](http://help.github.com/send-pull-requests/)

### On chat

- Slack (slack.puppet.com) #forge-modules, #puppet-dev, #windows, #voxpupuli
- IRC (freenode) #puppet-dev, #voxpupuli
