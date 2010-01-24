require 'rubygems'
require 'neo4jr-simple'
require 'fastercsv'
require 'haversine'
require 'model-utils'

# create a graph model of a transit system
# a demo of using the neo4j graph db from ruby via the neo4jr-simple gem

DATA_DIR = 'data'
STATION_LOCATIONS = File.join(DATA_DIR,'redline-stations.csv')
TRAVEL_TIMES = File.join(DATA_DIR,'redline-travel-times.csv')
DB_DIR = 'db'

WALKING_POINTS_PER_MILE = 10
BOX_PADDING_MILES = 2
MAX_WALK_MILES = 1.5
WALKING_SPEED_MPH = 3.0

DB = File.join(DB_DIR,'redlinemodel')
Neo4jr::Configuration.database_path = DB

def create_stops()
  FasterCSV.foreach(STATION_LOCATIONS,{:headers => true}) do |row|
    stop = db.createNode
    stop[:stop_id] = row['stop_id']
    stop[:lat] = row['stop_lat'].to_f
    stop[:lon] = row['stop_lon'].to_f
    register_stop(stop)
    puts "created stop db##{stop.getId} for #{stop[:stop_id]}"
  end
end

def create_transit_links
  stops_by_stop_id = index_stops_by(:stop_id)
  FasterCSV.foreach(TRAVEL_TIMES, {:headers => false}) do |row|
    stop1 = stops_by_stop_id[row[0]]
    stop2 = stops_by_stop_id[row[1]]
    time = row[2].to_f
    puts "linking #{row[0]} and #{row[1]} with a trip of #{time} minutes"
    #create bidirectional links
    r = stop1.createRelationshipTo(stop2,Neo4jr::RelationshipType.instance(:transit))
    r[:cost] = time
    r = stop2.createRelationshipTo(stop1,Neo4jr::RelationshipType.instance(:transit))
    r[:cost] = time
  end
end

# return two lat,lon points defining the NW and SE corners of a box encompassing the stations 
def compute_bounds(stations)
  north = south = stations.first['lat']
  east = west = stations.first['lon']
  stations.each do |station|
    lat = station['lat']
    lon = station['lon']
    north = lat if lat > north
    south = lat if lat < south
    east = lon if lon > east
    west = lon if lon < west
  end
  [[north,west],[south,east]]
end

# messy method that lays down a grid of points within 1.5 miles of transit nodes
# each point is cconnected to a transit node w/ an edge that has the cost in minutes to walk
def create_walking_sample_points
  stops_by_stop_id = index_stops_by(:stop_id)
  all_stops = stops_by_stop_id.values

 
  #compute a box bounding the stations
  nw, se = compute_bounds(stops_by_stop_id.values)
  
  #determine the width of the bounding box, and the degrees per mile factor
  box_width_degrees = (se.last - nw.last).abs
  box_width_miles = haversine_distance(se.first,nw.last,se.first,se.last)
  east_west_degrees_per_mile = box_width_degrees / box_width_miles
  
  #determine the height of the bounding box and the degrees per mile factor
  box_height_degrees = (se.first - nw.first).abs
  box_height_miles = haversine_distance(se.first,nw.last,nw.first,nw.last)
  north_south_degrees_per_mile = box_height_degrees / box_height_miles


  # pad the box to account for walking connections past the station bounds 
  width_degrees = box_width_degrees + 2 * BOX_PADDING_MILES * east_west_degrees_per_mile
  width_miles = box_width_miles + 2 * BOX_PADDING_MILES

  height_degrees = box_height_degrees + 2 * BOX_PADDING_MILES * north_south_degrees_per_mile
  height_miles = box_height_miles + 2 * BOX_PADDING_MILES

  x_points =  (width_miles * WALKING_POINTS_PER_MILE).ceil
  y_points =  (height_miles * WALKING_POINTS_PER_MILE).ceil

  puts "will create walking sample point grid #{x_points} wide * #{y_points} tall"
 
  x_increment = width_degrees/x_points
  y_increment = height_degrees/y_points
  
  walking_parent = get_walking_sample_list_node
  walk_rel_type = Neo4jr::RelationshipType.instance(:walking)

  starting_lat = nw.first + BOX_PADDING_MILES * north_south_degrees_per_mile
  lon = nw.last - BOX_PADDING_MILES * east_west_degrees_per_mile
  
  # lay down the grid, creating only the points within MAX_WALK_MILES of the station
  x_points.times do |x_idx|
    lat = starting_lat
    y_points.times do |y_idx|
      current_node = nil
      get_all_stops.to_a.each do |stop|
        #TODO - use a geometric index to find stations that have a reasonable likelihood of being close enough
        distance = haversine_distance(lat,lon,stop['lat'],stop['lon'])
        if distance < MAX_WALK_MILES
          if current_node.nil?
            current_node = db.createNode
            current_node['type'] = 'WalkingPoint'
            current_node['lat'] = lat
            current_node['lon'] = lon
            walking_parent.createRelationshipTo(current_node, Neo4jr::RelationshipType.instance(:walking_points))
          end
          rel = stop.createRelationshipTo(current_node,walk_rel_type)
          rel['distance'] = distance
          rel['cost'] = distance/WALKING_SPEED_MPH * 60.0
          puts "creating walking link of length #{distance}, time #{rel['cost']} to station #{stop['stop_id']}" 
        end
      end
      lat -= y_increment
    end
    lon += x_increment
  end

end



def create_model
  create_stops
  create_transit_links
  create_walking_sample_points
end


Neo4jr::DB.execute do |neo|
 create_model
end

puts "done, now run cost_at_station"


