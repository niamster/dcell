module DCell
  # misc helper functions
  module Utils
    class << self
      def symbolize!(h)
        return unless h.kind_of? Hash
        h.keys.each do |k|
          ks = k.to_sym
          val = h.delete k
          h[ks] = val
          if val.kind_of? Hash
            symbolize! val
          elsif val.kind_of? Array
            val.each do |entry|
              symbolize! entry
            end
          end
        end
      end

      def full_const_get(name)
        list = name.split("::")
        obj = Object
        list.each do |x|
          next if x.length == 0
          obj = obj.const_get x
        end
        obj
      end
    end
  end
end
