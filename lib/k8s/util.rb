# frozen_string_literal: true

module K8s
  # Miscellaneous helpers
  module Util
    PATH_TR_MAP = { '~' => '~0', '/' => '~1' }.freeze
    PATH_REGEX = %r{(/|~(?!1))}.freeze

    # Yield with all non-nil args, returning matching array with corresponding return values or nils.
    #
    # Args must be usable as hash keys. Duplicate args will all map to the same return value.
    #
    # @param args [Array<nil, Object>]
    # @yield args
    # @yieldparam args [Array<Object>] omitting any nil values
    # @return [Array<nil, Object>] matching args array 1:1, containing yielded values for non-nil args
    def self.compact_map(args)
      func_args = args.compact

      values = yield func_args

      # Hash{arg => value}
      value_map = Hash[func_args.zip(values)]

      args.map{ |arg| value_map[arg] }
    end

    # Produces a set of json-patch operations so that applying
    # the operations on a, gives you the results of b
    # Used in correctly patching the Kube resources on stack updates
    #
    # @param patch_to [Hash] Hash to compute patches against
    # @param patch_from [Hash] New Hash to compute patches "from"
    def self.json_patch(patch_to, patch_from)
      diffs = HashDiff.diff(patch_to, patch_from, array_path: true)
      ops = []
      # Each diff is like:
      # ["+", ["spec", "selector", "food"], "kebab"]
      # ["-", ["spec", "selector", "drink"], "pepsi"]
      # or
      # ["~", ["spec", "selector", "drink"], "old value", "new value"]
      # the path elements can be symbols too, depending on the input hashes
      diffs.each do |diff|
        operator = diff[0]
        # substitute '/' with '~1' and '~' with '~0'
        # according to RFC 6901
        path = diff[1].map { |p| p.to_s.gsub(PATH_REGEX, PATH_TR_MAP) }
        if operator == '-'
          ops << {
            op: "remove",
            path: "/" + path.join('/')
          }
        elsif operator == '+'
          ops << {
            op: "add",
            path: "/" + path.join('/'),
            value: diff[2]
          }
        elsif operator == '~'
          ops << {
            op: "replace",
            path: "/" + path.join('/'),
            value: diff[3]
          }
        else
          raise "Unknown diff operator: #{operator}!"
        end
      end

      ops
    end
  end
end
