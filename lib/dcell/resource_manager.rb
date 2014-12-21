module DCell
  class ResourceManager
    def initialize
      @lock = Mutex.new
      @items = {}
    end

    # Register an item inside the cache if it does not yet exist
    # If the item is not found inside the cache the block attached should return a valid reference
    def register(id, &block)
      @lock.synchronize do
        ref = @items[id]
        unless ref && ref.weakref_alive?
          item = block.call
          return nil unless item
          ref = WeakRef.new(item)
          @items[id] = ref
        end
        ref.__getobj__
      end
    end

    # Find an item by its ID
    def find(id)
      @lock.synchronize do
        begin
          ref = @items[id]
          return unless ref
          ref.__getobj__
        rescue WeakRef::RefError
          @items.delete id
          nil
        end
      end
    end

    # Delete item from the cache
    def delete(id)
      @lock.synchronize do
        @items.delete id
      end
    end
  end
end
