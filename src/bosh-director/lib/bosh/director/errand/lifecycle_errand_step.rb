module Bosh::Director
  class Errand::LifecycleErrandStep
    def initialize(runner, deployment_planner, name, instance, instance_group, keep_alive, deployment_name, logger)
      @runner = runner
      @deployment_planner = deployment_planner
      @errand_name = name
      @instance = instance
      @keep_alive = keep_alive
      @logger = logger
      instance_group_manager = Errand::InstanceGroupManager.new(@deployment_planner, instance_group, @logger)
      @errand_instance_updater = Errand::ErrandInstanceUpdater.new(instance_group_manager, @logger, @errand_name, deployment_name)
    end

    def prepare
      return if @skip_errand
      @errand_instance_updater.create_vms(@keep_alive)
    end

    def run(&checkpoint_block)
      begin
        result = nil
        @errand_instance_updater.with_updated_instances(@keep_alive) do
          @logger.info('Starting to run errand')
          result = @runner.run(@instance, &checkpoint_block)
        end
        result
      ensure
        @deployment_planner.template_blob_cache.clean_cache!
      end
    end

    def ignore_cancellation?
      @errand_instance_updater && @errand_instance_updater.ignore_cancellation?
    end

    def state_hash
      digest = ::Digest::SHA1.new


      digest << @instance.uuid

      digest << @instance.configuration_hash
      # rendered_templates_archive_model = @instance.model.latest_rendered_templates_archive
      # if rendered_templates_archive_model && rendered_templates_archive_model.content_sha1
      #   digest << rendered_templates_archive_model.content_sha1
      # else
      #   raise "NO RENDERED TEMPLATES FOUND for #{@instance}"
      # end

      digest << @instance.current_packages.to_s

      Config.logger.info("Computed configuration hash for #{@instance}: digest: '#{digest.hexdigest}', uuid: #{@instance.uuid}, templates sha1 #{rendered_templates_archive_model.content_sha1}, current_packages: #{@instance.current_packages.to_s}")

      digest.hexdigest
    end
  end
end
