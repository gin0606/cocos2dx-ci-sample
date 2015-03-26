require 'rake'

module TaskHelper
  private

  def unfold_options(options={}, prefix='-', seperator=' ')
    options.map { |k, v| %(#{prefix}#{k}#{seperator}'#{v}') }.join(" ")
  end

  # --- copy from `rake/file_utils.rb`
  def sh(*cmd, &block)
    options = (Hash === cmd.last) ? cmd.pop : {}
    shell_runner = block_given? ? block : create_shell_runner(cmd)
    set_verbose_option(options)
    options[:noop] ||= Rake::FileUtilsExt.nowrite_flag
    Rake.rake_check_options options, :noop, :verbose
    Rake.rake_output_message cmd.join(" ") if options[:verbose]

    unless options[:noop]
      res = rake_system(*cmd)
      status = $?
      status = Rake::PseudoStatus.new(1) if !res && status.nil?
      shell_runner.call(res, status)
    end
  end

  def create_shell_runner(cmd) # :nodoc:
    show_command = cmd.join(" ")
    show_command = show_command[0, 42] + "..." unless $trace
    lambda do |ok, status|
      ok or
        fail "Command failed with status (#{status.exitstatus}): " +
        "[#{show_command}]"
    end
  end

  def set_verbose_option(options) # :nodoc:
    unless options.key? :verbose
      options[:verbose] =
        (Rake::FileUtilsExt.verbose_flag == Rake::FileUtilsExt::DEFAULT) ||
        Rake::FileUtilsExt.verbose_flag
    end
  end

  def rake_system(*cmd) # :nodoc:
    Rake::AltSystem.system(*cmd)
  end
end
