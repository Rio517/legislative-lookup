Rake::TaskManager.class_eval do
  def delete_task(task_name)
    @tasks.delete(task_name.to_s)
  end
  # Rake.application.delete_task("db:test:purge")
  Rake.application.delete_task("db:test:prepare")
end

namespace :db do
  # http://stackoverflow.com/questions/5108876/kill-a-postgresql-session-connection
  desc "Fix 'database is being accessed by other users'"
  task :terminate_connections => :environment do
    ActiveRecord::Base.connection.execute <<-SQL
      SELECT
        pg_terminate_backend(pid)
      FROM
        pg_stat_activity
      WHERE
        -- don't kill my own connection!
        pid <> pg_backend_pid()
        -- don't kill the connections to other databases
        AND datname = '#{ActiveRecord::Base.connection.current_database}';
    SQL
  end
  task :add_postgis => :environment do
    ActiveRecord::Base.connection.execute('CREATE EXTENSION postgis;')
  end
  namespace :test do
    task :prepare => [:environment, :purge] do
      Rails.application.load_seed
    end
  end
end

Rake::Task["db:drop"].enhance ["db:terminate_connections"]