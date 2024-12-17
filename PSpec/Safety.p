// event: initialize the AtomicityInvariant spec monitor
type tMonitorSuccessor = (Id: int, successors: seq[tNode]);
event eMonitor_AtomicityInitialize;
event eSuccessorAltered: tMonitorSuccessor;
event eInitalizeSuccessors: tMonitorSuccessor;

// Note: Special care is needed when testing node failures and departures, since they can leave the successor list in an invalid state

/**
 * AtLeastOneRing property is defined as follows:
 * There must be a ring, which means there must be a non-empty set of ring members.
 */
spec AtLeastOneRing observes eSuccessorAltered, eMonitor_AtomicityInitialize, eInitalizeSuccessors
{
	var successorMap: map[int, seq[tNode]];

	var ring: bool;
	var visited: set[tNode];
	var startNode: tNode;
	var currNode: tNode;
	var i: int;
	var id: int;

	start state Init {
		on eMonitor_AtomicityInitialize goto WaitForEvents;
	}

	state WaitForEvents {
		on eInitalizeSuccessors do (package: tMonitorSuccessor) {
			successorMap[package.Id] = package.successors;
		}
		on eSuccessorAltered do (package: tMonitorSuccessor) {
			successorMap[package.Id] = package.successors;
			ring = false;
			foreach(id in keys(successorMap)) { // choose an arbitrary node as the starting node
				if(sizeof(successorMap[id]) == 0) {
					continue;
				}
				
				startNode = successorMap[id][0];
		  		currNode = startNode;
		  		
				i = 0;
				while (i < sizeof(successorMap)) {
					// Check whether a cycle is formed
					if(currNode in visited) {
						ring = true; // cycle ==> ring
						break;
			  		}

					// Add current node to visited nodes
					visited += (currNode);

					// Go to successor
					if((currNode.Id in keys(successorMap)) == false || sizeof(successorMap[currNode.Id]) == 0) {
						break;
					}
					currNode = successorMap[currNode.Id][0];
					i = i + 1;
				}
				if(i == sizeof(successorMap)){
					assert currNode.Id == startNode.Id, "Iterated over N nodes, but no cycle detected";
			  		ring = true;
				}
				if(ring) {
					print "Found At Least One Ring!";
					break;
				}
			}
			assert ring == true, "At Least One Ring not detected";
		}
	}
}

// Let r_x := a list of reachable nodes from x
// From any node pairs x, y:
//     assert  r_x <= r_y or r_y <= r_x ( <= is subset)

// func isSubset(x,y):
//     for each x_i in x:
//         assert x_i in y

/**
 * AtMostOneRing property is defined as follows:
 * There must be no more than one ring, which means that from each ring member, every other ring member is reachable by following the chain of successors.
 */
spec AtMostOneRing observes eSuccessorAltered, eMonitor_AtomicityInitialize, eInitalizeSuccessors
{
	var successorMap: map[int, seq[tNode]];

	var visited: set[tNode];
	var subsets: set[set[int]];
	var tmp: set[int];
	var curr: tNode;
	var i: int;
	var j: int;
	var id: int;
	var sub1: set[tNode];
	var sub2: set[tNode];

	start state Init {
		on eMonitor_AtomicityInitialize goto WaitForEvents;
	}

	state WaitForEvents {
		on eInitalizeSuccessors do (package: tMonitorSuccessor) {
			successorMap[package.Id] = package.successors;
		}
		on eSuccessorAltered do (package: tMonitorSuccessor) {
			successorMap[package.Id] = package.successors;
			
			// Generate (i,j) pair of all nodes
			subsets = default(set[set[int]]);
			tmp = default(set[int]);
			foreach(i in keys(successorMap)) {
				if(sizeof(successorMap[i]) == 0) {
					continue;
				}
				foreach(j in keys(successorMap)) {
					if(sizeof(successorMap[j]) == 0 || j == i) {
						continue;
					}
					tmp = default(set[int]);
					tmp += (i);
					tmp += (j);
					subsets += (tmp);
				}
			}
			
			sub1 = default(set[tNode]);
			sub2 = default(set[tNode]);
			
			// For each (i,j) node pairs
			foreach(tmp in subsets) {
				// Generate a list of nodes reachable from i and j
				sub1 = GetReachableNodes(tmp[0]);
				sub2 = GetReachableNodes(tmp[1]);

				// Ensure that one is a subset of the other
				// By guaranteeing that one is a subset of the other, we ensure that the nodes are reachable from each other (since we try every pair of nodes)
				// Note: We do not need to check for equality, since the nodes may be temporarily unreachable due to a node failure or departure
				assert IsSubset(sub1, sub2) || IsSubset(sub2, sub1), format("{0} : {1} : {2}", sub1, sub2, successorMap);
			}
		}
	}

	// Helper functions for AtMostOneRing
	/**
	 * GetReachableNodes function returns a set of nodes reachable from a given node.
	 */
	
	fun GetReachableNodes(id: int) : set[tNode]	{
		visited = default(set[tNode]);
		curr = successorMap[id][0];
		i = 0;
		while (i < sizeof(successorMap)) {
			if(curr in visited) {
				break;
			}
			visited += (curr);
			if((curr.Id in keys(successorMap)) == false || sizeof(successorMap[curr.Id]) == 0) {
				return visited;
			}
			curr = successorMap[curr.Id][0];
			i = i + 1;
		}
		return visited;
	}

	/**
	 * IsSubset function checks if set x is a subset of set y.
	 */
	fun IsSubset(x: set[tNode], y: set[tNode]) : bool {
		// X is a subset of Y if for every element in X, it is also in Y
		foreach(curr in x) {
			if((curr in y) == false) {
				return false;
			}
		}
		return true;
	}
}
/*
OrderedRing:
for every node:
  for every successor node:
	if successosr <= node
	  for every successor node:
		successor successor <= node
		  until we reach the node we started from
*/

/**
 * OrderedRing property is defined as follows:
 * On the unique ring, the nodes must be in identifier order.
 */
spec OrderedRing observes eSuccessorAltered, eMonitor_AtomicityInitialize, eInitalizeSuccessors
{
	var successorMap: map[int, seq[tNode]];
	var numOrderingChange: int;

	var visited: set[tNode];
	var lastVisitedNode: tNode;
	var currNode: tNode;
	var i: int;
	var id: int;

	start state Init {
		on eMonitor_AtomicityInitialize goto WaitForEvents;
	}
	
	state WaitForEvents {
		on eInitalizeSuccessors do (package: tMonitorSuccessor) {
			successorMap[package.Id] = package.successors;
		}

		on eSuccessorAltered do (package: tMonitorSuccessor) {
			successorMap[package.Id] = package.successors;
			
			// For each sucessor node, there can be at most one instance in which the ordering decreases (when going from node n to node 0)
			foreach(id in keys(successorMap)) {
				if(sizeof(successorMap[id]) == 0) {
					continue;
				}			
				
				numOrderingChange = 0;
				lastVisitedNode = successorMap[id][0];
				currNode = lastVisitedNode;
				
				i = 0;
				while (i < sizeof(successorMap)) {
					if(currNode in visited) {
						break;
					}
					
					if(lastVisitedNode.Id > currNode.Id) {
						numOrderingChange = numOrderingChange + 1;
					}
					
					visited += (currNode);
					lastVisitedNode = currNode;
					
					// Go to successor
					if((currNode.Id in keys(successorMap)) == false || sizeof(successorMap[currNode.Id]) == 0) {
						break;
					}
					currNode = successorMap[currNode.Id][0];
					i = i + 1;
				}
				assert numOrderingChange <= 2, "More than one ordering change detected";
			}
		}
	}
}