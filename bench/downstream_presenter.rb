# /usr/bin/env ruby

require ::File.expand_path('../../config/environment', __FILE__)
require 'benchmark'

large_reverse = Link.find_by_sql(<<-SQL).first[:target_content_id]
  SELECT target_content_id
  FROM links
  GROUP BY target_content_id
  ORDER BY COUNT (*) DESC
  LIMIT 1
SQL

large_forward = LinkSet.find_by_sql(<<-SQL).first[:content_id]
  SELECT content_id
  FROM link_sets
  WHERE id IN (
    SELECT link_set_id
    FROM links
    GROUP BY link_set_id
    ORDER BY COUNT(*) DESC
    LIMIT 1
  )
SQL

no_links = Link.find_by_sql(<<-SQL).first[:content_id]
  SELECT content_id
  FROM link_sets
  LEFT JOIN links
  ON links.link_set_id = link_sets.id
  OR links.target_content_id = link_sets.content_id
  WHERE links.id IS NULL
  LIMIT 1
SQL

single_link = Link.find_by_sql(<<-SQL).first[:content_id]
  SELECT content_id
  FROM link_sets
  INNER JOIN links ON links.target_content_id = link_sets.content_id
  GROUP BY content_id
  HAVING COUNT(*) = 1
  LIMIT 1
SQL

benchmarks = {
  'Many reverse dependencies' => large_reverse,
  'Many forward dependencies' => large_forward,
  'No dependencies' => no_links,
  'Single link each way' => single_link
}

benchmarks.each do |name, content_id|
  content_item = Queries::GetLatest.(ContentItemFilter.new(
    scope: ContentItem.where(content_id: content_id)
  ).filter(state: 'published')).first

  puts "#{name}: #{content_id}"
  puts Benchmark.measure {
    10.times do |i|
      Rails.logger.debug "Iteration #{i}"
      Rails.logger.debug "-----------"
      Presenters::DownstreamPresenter.present(
        content_item,
        state_fallback_order: Adapters::ContentStore::DEPENDENCY_FALLBACK_ORDER
      )
      print "."
    end
    puts ""
  }
end
