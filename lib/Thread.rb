 module ImageProcessThread
  class << self
    attr_accessor :execute_thread
    attr_accessor :last_commit_time
    attr_accessor :last_commit_description
    def initialize
      @execute_thread = nil
      @last_commit_time = ''
      @last_commit_description = ''
    end

    def is_busy?
      @execute_thread != nil
    end

    def execute(description, &block)
      return false if @execute_thread != nil
      @last_commit_time = Time.now
      @last_commit_description = description
      @execute_thread = Thread.new do
        block.call
        @execute_thread = nil
        ygopro_images_manager_logger.info "Task [#{@last_commit_description}] started on #{@last_commit_time} is Finished."
      end
      true
    end

    def abort
      if @execute_thread == nil
        ygopro_images_manager_logger.warn "No thread is running but request to abort."
        false
      else
        @execute_thread.kill
        true
      end
    end
  end
 end

 ImageProcessThread.initialize