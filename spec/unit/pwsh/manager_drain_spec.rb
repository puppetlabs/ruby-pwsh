# frozen_string_literal: true

require 'spec_helper'
require 'ruby-pwsh'

RSpec.describe Pwsh::Manager do
  describe '#drain_pipe_until_signaled' do
    let(:manager) { described_class.allocate }
    let(:pipes) { IO.pipe }
    let(:reader) { pipes[0] }
    let(:writer) { pipes[1] }
    let(:signal) { Mutex.new }

    after do
      reader.close
      writer.close
    end

    it 'returns everything written before the signal without waiting on the open, empty pipe' do
      signal.lock
      drain = Thread.new do
        output = manager.send(:drain_pipe_until_signaled, reader, signal)
        [output, Process.clock_gettime(Process::CLOCK_MONOTONIC)]
      end

      writer.write('hello')
      sleep 0.2
      writer.write(' world')
      released_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      signal.unlock
      output, finished_at = drain.value

      expect(output).to eq(['hello world'])
      expect(finished_at - released_at).to be < 0.3
    end

    it 'returns an empty array when nothing was written' do
      expect(manager.send(:drain_pipe_until_signaled, reader, signal)).to eq([])
    end
  end
end
