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
    job_cost = job_cost.sort.reverse

    (@workers - 1).times do |t|
      idx = 0
      chunk = []
      chunk << job_cost.slice!(idx)

      while (sum = chunk.sum) <= avg && job_cost[idx] do
        if job_cost[idx] > (avg - sum)
          idx = idx + 1
        else
          chunk << job_cost.slice!(idx)
        end
      end

      batches << chunk
    end

    batches << job_cost
  end

  def self.benchmark(workers, times, array_elements)
    a = []
    array_elements.times { a << rand(100) }
    n = times
    Benchmark.bmbm do |x|
      x.report(:test) { n.times { OptimizedWorkerUsage.new(workers, a).create_equal_batches } }
    end
  end
end
