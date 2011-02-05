require 'adapter'
require 'memcached'

module Adapter
  module Memcached
    def read(key)
      decode(client.get(key_for(key)))
    rescue ::Memcached::NotFound
    end

    def write(key, value)
      client.set(key_for(key), encode(value))
    end

    def delete(key)
      read(key).tap { client.delete(key_for(key)) }
    rescue ::Memcached::NotFound
    end

    def clear
      client.flush
    end

    def lock(name, options={}, &block)
      key           = key_for(name)
      start         = Time.now
      lock_acquired = false
      expiration    = options.fetch(:expiration, 1)
      timeout       = options.fetch(:timeout, 5)

      while (Time.now - start) < timeout
        begin
          client.add(key, 'locked', expiration)
          lock_acquired = true
          break
        rescue ::Memcached::NotStored
          sleep 0.1
        end
      end

      raise(Adapter::LockTimeout.new(name, timeout)) unless lock_acquired

      begin
        yield
      ensure
        begin
          client.delete(key)
        rescue ::Memcached::NotFound
        end
      end
    end
  end
end

Adapter.define(:memcached, Adapter::Memcached)