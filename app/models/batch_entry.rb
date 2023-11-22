class BatchEntry < ActiveRecord::Base
  serialize :result
  belongs_to :job, :class_name => "BatchJob", :foreign_key => :batch_job_id, :inverse_of => :entries

  validates :state, :inclusion => {:in => %w(started failed succeeded skipped), :allow_nil => true}

  def succeeded?
    state == "succeeded"
  end

  def failed?
    state == "failed"
  end

  def skipped?
    state == "skipped"
  end

  def complete?
    failed? || succeeded? || skipped?
  end

  def check_job_complete
    job.check_complete if complete? && job
  end
end
