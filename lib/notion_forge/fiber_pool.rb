# frozen_string_literal: true

module NotionForge
  class FiberPool
    def initialize(size: 10)
      @size = size
      @queue = []
      @fibers = []
    end

    def schedule(&block)
      @queue << block
      process_queue
    end

    def wait_all
      process_queue until @queue.empty? && @fibers.all? { !_1.alive? }
    end

    private

    def process_queue
      while @fibers.count(&:alive?) < @size && @queue.any?
        task = @queue.shift
        fiber = Fiber.new { task.call }
        @fibers << fiber
        fiber.resume
      end

      @fibers.reject! { !_1.alive? }
    end
  end
end
