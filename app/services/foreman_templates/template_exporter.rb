module ForemanTemplates
  # TODO cover with tests (not much to cover though, it will be a lot of stubbing)
  class TemplateExporter
    delegate :logger, :to => :Rails

    # TODO expose metadata_export_mode in settings too
    def self.setting_overrides
      # associate
      %i(verbose prefix dirname filter repo negate branch metadata_export_mode)
    end

    attr_reader *setting_overrides

    # TODO dry-up with importer
    def initialize(args = {})
      assign_attributes args
      # Rake hands off strings, not booleans, and "false" is true...
      if @verbose.is_a?(String)
        @verbose = if @verbose == 'false'
                     false
                   else
                     true
                   end
      end
    end

    def export!
      @dir = Dir.mktmpdir

      git_repo = Git.clone(@repo, @dir)
      logger.debug "cloned #{@repo} to #{@dir}"
      branch = @branch ? @branch : get_default_branch(git_repo)
      git_repo.checkout(branch) if branch

      dump_files!

      git_repo.add
      # TODO make commit and push actions optional, in such case we can't destroy temp directory though,
      # maybe in such case we need file adapter that could just update files, consult with xprazak who works on file
      # adapter for importing
      git_repo.commit "Templates export made by Foreman user #{User.current.try(:login) || User::ANONYMOUS_ADMIN}"
      git_repo.push 'origin', branch

      return true
    ensure
      FileUtils.remove_entry_secure(@dir) if File.exist?(@dir)
    end

    def dump_files!
      # TODO finalize the directory structure
      # TODO use filter attribute, verbose, dirname
      Template.unscoped.map do |template|
        current_dir = File.join(@dir, template.model_name.human.pluralize.downcase.tr(' ', '_'))
        FileUtils.mkdir_p current_dir
        filename = File.join(current_dir, template.name.downcase.tr(' ', '_') + '.erb')
        File.open(filename, 'w+') do |file|
          logger.debug "Writing to file #{filename}"
          bytes = file.write template.public_send(export_method)
          logger.debug "finished writing #{bytes}"
        end
      end
    end

    # * refresh - template.to_erb stripping existing metadata,
    # * remove  - just template.template with stripping existing metadata,
    # * keep    - taking the whole template.template
    def export_method
      case @metadata_export_mode
        when 'refresh'
          :to_erb
        when 'remove'
          :template_without_metadata
        when 'keep'
          :template
        else
          raise "Unknown metadata export mode #{@metadata_export_mode}"
      end
    end

    private

    def assign_attributes(args = {})
      self.class.setting_overrides.each do |attribute|
        instance_variable_set("@#{attribute}", args[attribute.to_sym] || Setting["template_sync_#{attribute}".to_sym])
      end
    end
  end
end
