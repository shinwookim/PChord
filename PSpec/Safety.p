// event: initialize the AtomicityInvariant spec monitor
type tMonitorSuccesor = (Id: int, successors: seq[tNode]);
event eMonitor_AtomicityInitialize;
event eSuccessorAltered: tMonitorSuccesor;
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
spec AtLeastOneRing observes eSuccessorAltered, eMonitor_AtomicityInitialize
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
      on eSuccessorAltered goto HandleEvents;
    }

    state HandleEvents {
      entry (package: tMonitorSuccesor) {
        successorMap[package.Id] = package.successors;

        foreach(id in keys(successorMap)) {
          // Choose a random starting node
          startNode = successorMap[id][0];
          currNode = startNode;
          i = 0;
          while (i < sizeof(successorMap)) {
              // Cycle already detected -> one ring exists
              if(currNode in visited) {
                  ring = true;
                  break;
              }
              // Add current node to visited nodes
              visited += (currNode);
              // Go to successor
              currNode = successorMap[currNode.Id][0];
              i = i + 1;
          }

          if(i == sizeof(successorMap)){
              assert currNode.Id == startNode.Id, "Iterated over N nodes, but no cycle detected";
              ring = true;
          }

          if(ring) {
            break;
          }
        }
        assert ring == true, "At Least One Ring not detected";
      }
    }
}