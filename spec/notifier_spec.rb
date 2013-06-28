require 'spec_helper'

describe Celluloid::Dashboard::Notifier do
  before(:each) do
    Celluloid.shutdown
    Celluloid.boot
    subject # initialize, somehow needed.
  end
  
  it 'saves notifications' do
    Celluloid::Notifications.notifier.publish('foo', :bar, 42)
    expect(subject.notifications).to have(1).notification
  end

  it 'clears notifications' do
    Celluloid::Notifications.notifier.publish('foo', :bar, 42)
    expect(subject.notifications).to have(1).notification
    subject.clear
    expect(subject.notifications).to have(0).notification
  end

  it 'saves the arguments correctly' do
    Celluloid::Notifications.notifier.publish('foo', :bar, 42)
    n = subject.notifications.first
    expect(n[:time]).to be_within(2).of(Time.now)
    expect(n[:topic]).to eq('foo')
    expect(n[:args]).to eq([:bar, 42])
  end

  it 'pops the log' do
    max_notifications = Celluloid::Dashboard::Notifier::MAX_NOTIFICATIONS
    (max_notifications + 5).times do
      Celluloid::Notifications.notifier.publish('foo', :bar, 42)
    end
    expect(subject.notifications).to have(max_notifications).notification
  end

  it 'notifys Application when Dashboard is running' do
    Celluloid::Dashboard.stub(:running?) { true }
    expect(Celluloid::Dashboard::Application).to(receive(:notify).once)
    Celluloid::Notifications.notifier.publish('foo', :bar, 42)
  end

  it 'does not notify Application when Dashboard is not running' do
    Celluloid::Dashboard.stub(:running?) { false }
    expect(Celluloid::Dashboard::Application).to_not(receive(:notify))
    Celluloid::Notifications.notifier.publish('foo', :bar, 42)
  end
end
