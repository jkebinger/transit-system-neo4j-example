

def db
 Neo4jr::DB.instance
end


def find_or_create_sub_reference_node(rel_type,node_name)
  ref_node = db.get_reference_node
  rel = ref_node.getSingleRelationship(rel_type,Neo4jr::Direction::OUTGOING)
  if rel
    rel.getEndNode
  else
    node = db.createNode
    ref_node.createRelationshipTo(node,rel_type)
    node[:name] = node_name
    node
  end
end

def get_stop_list_node()
  find_or_create_sub_reference_node(Neo4jr::RelationshipType.instance(:stations),'StopRefNode')
end

def get_walking_sample_list_node
  find_or_create_sub_reference_node(Neo4jr::RelationshipType.instance(:walking_points),'WalkingPointsRefNode')
end


def register_stop(node)
  get_stop_list_node.createRelationshipTo(node, Neo4jr::RelationshipType.instance(:stations))
end

def traverse_nodes(node,relationship)
  order         = Neo4jr::Order::BREADTH_FIRST
  stop_when     = Neo4jr::StopEvaluator::END_OF_GRAPH
  return_when   = Neo4jr::ReturnableEvaluator::ALL_BUT_START_NODE
  node.traverse(order,stop_when,return_when,relationship)
end

def get_all_stops()
  relationship = Neo4jr::RelationshipType.outgoing(:stations)
  traverse_nodes(get_stop_list_node, relationship).getAllNodes
end

def get_all_walking_points()
  w = get_walking_sample_list_node
  relationship = Neo4jr::RelationshipType.outgoing(:walking_points)
  traverse_nodes(get_walking_sample_list_node, relationship).getAllNodes
end

def index_stops_by(field)
  index = {}
  get_all_stops.each do |stop|
    index[stop[field]]= stop
  end
  index
end

