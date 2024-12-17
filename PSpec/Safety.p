// event: initialize the AtomicityInvariant spec monitor
type tMonitorSuccessor = (Id: int, successors: seq[tNode]);
event eMonitor_AtomicityInitialize;
event eSuccessorAltered: tMonitorSuccessor;
event eInitalizeSuccessors: tMonitorSuccessor;
/*
OrderedRing:
for every node:
  for every successor node:
    if successosr <= node
      for every successor node:
        successor successor <= node
          until we reach the node we started from
*/

/* 
  Note: Must be careful when testing nodes failure and departure such that a combination of nodes
  invalidate the successor list
*/

/**********************************
We would like to assert the AtLeastOneRing property that:
There must be a ring, which means there must be a non-empty set of ring members.
***********************************/
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
        foreach(id in keys(successorMap)) {
          // Choose a random starting node
          if(sizeof(successorMap[id]) == 0) {continue;}
          startNode = successorMap[id][0];
          currNode = startNode;
          i = 0;
          while (i < sizeof(successorMap)) {
              // Cycle already detected -> one ring exists
              print format("{0}", currNode.Id);
              if(currNode in visited) {
                  ring = true;
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

      // Get each pair of nodes
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

      foreach(tmp in subsets) {
        sub1 = GetReachableNodes(tmp[0]);
        sub2 = GetReachableNodes(tmp[1]);
        assert IsSubset(sub1, sub2) || IsSubset(sub2, sub1), format("{0} : {1} : {2}", sub1, sub2, successorMap);
      }
    }
  }

  fun GetReachableNodes(id: int) : set[tNode]
  {
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

  fun IsSubset(x: set[tNode], y: set[tNode]) : bool
  {
    foreach(curr in x) {
      if((curr in y) == false) {
        return false;
      }
    }

    return true;
  }
}


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
              if (lastVisitedNode.Id > currNode.Id) {
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
        }
        assert numOrderingChange <= 1, "More than one ordering change detected";
      }
    }
}