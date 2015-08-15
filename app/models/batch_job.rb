class BatchJob < ActiveRecord::Base
  has_many :entries, :class_name => "BatchEntry", :foreign_key => :batch_job_id

  serialize :on_complete_args, Array

  validates :state, :inclusion => {:in => %w(finalizing), :allow_nil => true}

  def self.perform_async(workers, worker_args, job_attributes)
    new_entries = workers.size.times.collect { BatchEntry.new }
    create!(job_attributes.merge(:entries => new_entries))

    workers.zip(new_entries).each do |w, e|
      w.perform_async(e.id, *worker_args)
    end
  end

  def on_complete_class
    super.try(:constantize)
  end

  def on_complete_class=(klass)
    super(klass.to_s)
  end

  def finalizing?
    state == "finalizing"
  end

  def expired?
    expires_at && Time.now > expires_at
  end

  def complete?
    expired? || entries.all?(&:complete?)
  end
end
