class OptimizedWorkerUsage
  def initialize(workers, job_cost)
    @job_cost = job_cost
    @workers = workers
  end

  def create_equal_batches
    job_cost = @job_cost.dup
    avg = (job_cost.sum / @workers).to_f
    batches = []
    chunk = []

    (@workers - 1).times do |t|
      idx_of_max = job_cost.index(job_cost.max)
      chunk << job_cost.slice!(idx_of_max)

      while job_cost.any? && job_cost.min <= (avg - chunk.sum) do
        idx_of_min = job_cost.index(job_cost.min)
        chunk << job_cost.slice!(idx_of_min)
      end
      batches << chunk
      chunk = []
    end

    batches << job_cost
  end

  def self.benchmark(workers, times, array_elements)
    a = []
    array_elements.times {  a << rand(100) }
    n = times
    Benchmark.bmbm do |x|
      x.report(:test) { n.times { OptimizedWorkerUsage.new(workers, a).create_equal_batches } }
    end
  end
end
