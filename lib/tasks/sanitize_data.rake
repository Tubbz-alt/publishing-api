desc "Sanitize access limited data"
task sanitize_data: :environment do
  Tasks::DataSanitizer.delete_access_limited(STDOUT)
end

namespace :db do
  desc "Resolves invalid versions detected by validate:versions task"
  task resolve_invalid_versions: :environment do
    Tasks::VersionResolver.resolve
  end
end
