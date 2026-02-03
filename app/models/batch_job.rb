class BatchJob < ActiveRecord::Base
  has_many :entries, :class_name => "BatchEntry", :dependent => :destroy, :inverse_of => :job

  serialize :on_complete_args, :coder => YAML, :type => Array

  validates :state, :inclusion => {:in => %w(finalizing), :allow_nil => true}

  SEMAPHORE = Mutex.new

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

  def entries_complete?
    entries.all?(&:complete?) && entries.any?
  end

  def check_complete
    # NOTE: The mutex may need to be upgraded to a database row lock
    #       if we go multi-process
    SEMAPHORE.synchronize do
      begin
        reload
      rescue ActiveRecord::RecordNotFound
        return
      end

      return if finalizing?
      return unless expired? || entries_complete?
      finalize!
    end
  end

  private

  def finalize!
    if on_complete_class
      update!(:state => "finalizing")
      on_complete_class.perform_async(id, *on_complete_args)
    else
      destroy
    end
  end
end
