// event: initialize the AtomicityInvariant spec monitor
event eMonitor_AtomicityInitialize: int;


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
spec AtLeastOneRing observes eVerify
{
    var nodes: set[Node];

    start state Init {
        defer eJoin, eLeave, eShutDown;
        on eMonitor_AtLeastOneRing goto WaitForEvents;
    }

    state WaitForEvents {
        on eVerify do {
            assert sizeof(nodes) > 0;

            var visited: set[Node];
            var startNode: Node;
            var currNode: Node;
            var i: int;

            // Choose a random starting node
            startNode = choose(nodes);
            currNode = startNode.succesorList[0];

            while (i < sizeof(noddes)) {
                // Cycle already detected -> one ring exists
                if(currNode in visited) {
                    break;
                }
                // Add current node to visited nodes
                visited += currNode;
                // Go to successor
                currNode = currNode.succesor[0];
            }

            if(i == sizeof(nodes)){
                assert currNode.Id == startNode.Id;
            }
        }
    }
}