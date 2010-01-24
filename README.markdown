## Neo4j transit network demo code

This code generated the data behind a [visualization](http://www.monkeyatlarge.com/projects/redline-travel-time/) of transit times from points across the Boston metro area to Park Street station via just one of the transit lines in the MBTA system.

It isn't well polished Ruby by any stretch, but there aren't a lot of example code for Neo4j and even less for using it from Ruby via the neo4jr-simple gem, so I thought someone might find it useful.

The project page is http://www.monkeyatlarge.com/projects/redline-travel-time/

### About the code

create_model.rb contains code to read data about station locations and travel times from the included files (derived from MBTA's GTFS feed) and build a graph model of the red line along with a grid of walking points located every tenth of a mile connected to every station within 1.5 miles.

cost_at_station.rb uses the model created in create_model to print out a file of transit times at various lat,lon points

model_utils.rb contains shared code used by both the above files

haversine.rb contains an implementation by Landon Cox of the haversine distance calculation used to calculate the distance in miles between two points


