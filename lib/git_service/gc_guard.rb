module GitService
  # Disables GC for the duration of a block. Workaround for a suspected libgit2
  # deadlock: Rugged uses Ruby's xmalloc as libgit2's allocator, so we believe a
  # GC can run inside git_mwindow_get_pack while it holds git_mwindow__mutex,
  # and finalizing another Rugged::Repository then re-locks that mutex on the
  # same thread (git_mwindow_put_pack), hanging the whole process.
  #
  # Only the guarded block is protected. We believe other libgit2 paths may
  # have the same problem.
  #
  # GC.disable is process-global, so this is refcounted. GC is re-enabled when
  # the last guard exits, unless it was already disabled beforehand.
  module GcGuard
    MUTEX = Mutex.new
    @count        = 0
    @was_disabled = false

    def self.without_gc
      MUTEX.synchronize do
        @was_disabled = GC.disable if @count.zero?
        @count += 1
      end

      yield
    ensure
      MUTEX.synchronize do
        @count -= 1
        GC.enable if @count.zero? && !@was_disabled
      end
    end
  end
end
