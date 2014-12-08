require 'objspace'

module Memprof2
  class << self
    def start
      ObjectSpace.trace_object_allocations_start
    end

    def stop
      ObjectSpace.trace_object_allocations_stop
      ObjectSpace.trace_object_allocations_clear
    end

    def run(&block)
      ObjectSpace.trace_object_allocations(&block)
    end

    def report(opts={})
      ObjectSpace.trace_object_allocations_stop
      configure(opts)
      results = collect_info
      File.open(@out, 'w') do |io|
        results.each do |location, memsize|
          io.puts "#{memsize} #{location}"
        end
      end
    ensure
      ObjectSpace.trace_object_allocations_start
    end

    private

    def configure(opts = {})
      @rvalue_size = GC::INTERNAL_CONSTANTS[:RVALUE_SIZE]
      if @trace = opts[:trace]
        raise ArgumentError, "`trace` option must be a Regexp object" unless @trace.is_a?(Regexp)
      end
      if @ignore = opts[:ignore]
        raise ArgumentError, "`ignore` option must be a Regexp object" unless @ignore.is_a?(Regexp)
      end
      @out = opts[:out] || "/dev/stdout"
    end

    def collect_info
      results = {}
      ObjectSpace.each_object do |o|
        next unless (file = ObjectSpace.allocation_sourcefile(o))
        next if file == __FILE__
        next if (@trace  and @trace !~ file)
        next if (@ignore and @ignore =~ file)
        line = ObjectSpace.allocation_sourceline(o)
        memsize = ObjectSpace.memsize_of(o) + @rvalue_size
        memsize = @rvalue_size if memsize > 100_000_000_000 # compensate for API bug
        klass = o.class.name rescue "BasicObject"
        location = "#{file}:#{line}:#{klass}"
        results[location] ||= 0
        results[location] += memsize
      end
      results
    end
  end
end


