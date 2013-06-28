require 'spec_helper'

describe Celluloid::Dashboard do
  subject { Celluloid::Dashboard }
  after(:each) { subject.stop }

  it 'can be started' do
    subject.start
    sleep 0.1
    expect(subject).to be_running
  end

  it 'can be stopped' do
    subject.start
    sleep 0.1
    subject.stop
    expect(subject).not_to be_running
  end
end
