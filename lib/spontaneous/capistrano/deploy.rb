
Capistrano::Configuration.instance(:must_exist).load do
  set :normalize_asset_timestamps, false

  set :bundle_cmd,              "bundle"
  set :bundle_flags,            "--deployment --quiet --binstubs --shebang ruby-local-exec"

  # Remove tmp/pids from list of shared dirs that get symlinked into the release
  set :shared_children,   %w(public/system log)

  set :media_dir,   lambda { "#{deploy_to}/media" }
  set :revision_dir, lambda { "#{deploy_to}/revisions" }
  set :upload_dir, lambda { "#{deploy_to}/uploadcache" }

  namespace :spot do
    task :symlink_cache do
      cache_dir = File.join(latest_release, 'cache')
      run "mkdir #{cache_dir}; ln -s #{deploy_to}/media #{cache_dir}; ln -s #{deploy_to}/revisions #{cache_dir}; ln -s #{deploy_to}/uploadcache #{cache_dir}/tmp"
    end

    task :symlink_application do
      run "cd #{release_path} && ln -s `bundle show spontaneous`/application public/.spontaneous"
    end

    # Capistrano automatically creates a tmp directory - I don't like that
    # and would prefer to share tmp between instances
    task :symlink_tmpdir do
      run "cd #{release_path} && rmdir tmp ; ln -nfs #{deploy_to}/shared/tmp ."
    end

    task :bundle_assets do
      run "cd #{release_path} && ./bin/spot assets compile --destination=#{release_path}"
    end
  end

  namespace :deploy do
    task :migrate, :roles => :db do
      spot_env = fetch(:spot_env, "production")
      run "cd #{latest_release} && SPOT_ENV=#{spot_env} ./bin/spot migrate"
    end
  end

  after 'deploy:finalize_update', 'spot:symlink_cache'
  after 'deploy:finalize_update', 'spot:symlink_tmpdir'
  after 'bundle:install', 'spot:symlink_application'
  after 'bundle:install', 'spot:bundle_assets'
end
