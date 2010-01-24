require 'rubygems'
require 'neo4jr-simple'
require 'model-utils'
require 'fastercsv'

# evaluates the transit model - computes transit times to a given station from a predefined grid of points

SSSPDijkstra = org.neo4j.graphalgo.shortestpath.SingleSourceShortestPathDijkstra
DoubleEvaluator = org.neo4j.graphalgo.shortestpath.std.DoubleEvaluator 
DoubleComparator = org.neo4j.graphalgo.shortestpath.std.DoubleComparator
DoubleAdder = org.neo4j.graphalgo.shortestpath.std.DoubleAdder


DB = File.join('db','redlinemodel')
Neo4jr::Configuration.database_path = DB


def create_output(stop)
  travel = Neo4jr::RelationshipType.instance(:transit)
  walk = Neo4jr::RelationshipType.instance(:walking)  

  types = travel.to_a + walk.to_a #this is weird, but Jruby wants an array of RelationShiptTypes not a ruby array
 
  # run Dijkstra's algorithm
  s = SSSPDijkstra.new(0.0,stop, DoubleEvaluator.new("cost"), 
    DoubleAdder.new, DoubleComparator.new, Neo4jr::Direction::BOTH,types)
  
  FasterCSV.open("#{stop['stop_id']}-travel-times.csv", "w") do |csv|
    csv << ['lat','lon','cost']
    get_all_walking_points.each do |pt|
      csv << [pt['lat'], pt['lon'], s.getCost(pt)] 
    end
  end
end

#TODO - make this a read-only transaction...
Neo4jr::DB.execute do |neo|
  stops_by_stop_id = index_stops_by(:stop_id)
  station_list = stops_by_stop_id.keys.sort.join(', ')
  if stops_by_stop_id.empty?
    puts "no stops found, have you run create_model.rb yet?"
  end
  if ARGV.length == 0
    puts "please specify a station id to compute travel times to"
    puts "pick one of #{station_list}"
  else
    stop = stops_by_stop_id[ARGV.first]
    if stop
      puts "writing data to #{ARGV.first}-travel-times.csv"
      create_output stop
    else
      puts "no stop found for #{ARGV.first}"
      puts "pick one of #{station_list}"
    end
  end
end
