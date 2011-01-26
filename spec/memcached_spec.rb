require 'helper'
require 'adapter/memcached'

describe "Memcached adapter" do
  before do
    @client = Memcached.new('localhost:11211', :namespace => 'adapter_spec')
    @adapter = Adapter[:memcached].new(@client)
    @adapter.clear
  end

  let(:adapter) { @adapter }
  let(:client)  { @client }

  it_should_behave_like 'a marshaled adapter'

  describe "#lock" do
    let(:lock_key)    { :add_game }
    let(:lock_value)  { 'locked' }

    it "defaults expiration to 1" do
      client.should_receive(:add).with(lock_key.to_s, lock_value, 1)
      adapter.lock(lock_key) { }
    end

    it "allows setting expiration" do
      client.should_receive(:add).with(lock_key.to_s, lock_value, 5)
      adapter.lock(lock_key, :expiration => 5) { }
    end

    describe "with no existing lock" do
      it "acquires lock, performs block, and clears lock" do
        result = false
        adapter.lock(lock_key) { result = true }

        result.should be_true
        adapter.read(lock_key).should be_nil
      end
    end

    describe "with lock set" do
      it "waits for unlock, performs block, and clears lock" do
        result = false
        client.add(lock_key.to_s, lock_value, 1)
        adapter.lock(lock_key, :timeout => 2) { result = true }

        result.should be_true
        adapter.read(lock_key).should be_nil
      end
    end

    describe "with lock set that does not expire before timeout" do
      it "raises lock timeout error" do
        result = false
        client.add(lock_key.to_s, lock_value, 2)

        lambda do
          adapter.lock(lock_key, :timeout => 1) { result = true }
        end.should raise_error(Adapter::LockTimeout, 'Timeout on lock add_game exceeded 1 sec')
      end
    end
  end
end