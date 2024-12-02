// User Defined Types
enum tTransStatus {
    SUCCESS,
    ERROR,
    TIMEOUT,
}

type tTrans : (key: string, val: int, transId: int);
type tWriteTransReq = (client: Client, trans: tTrans);
type tWriteTransResp = (transId: int, status: tTransStatus);
type tReadTransReq = (client: Client, key: string);
type tReadTransResp = (trans: tTrans, status: tTransStatus);

/* Events used by clients to communicate with nodes in Chord */
// event: write transaction request (client to coordinator)
event eWriteTransReq : tWriteTransReq;
// event: write transaction response (coordinator to client)
event eWriteTransResp : tWriteTransResp;
// event: read transaction request (client to coordinator)
event eReadTransReq : tReadTransReq;
// event: read transaction response (participant to client)
event eReadTransResp: tReadTransResp;

/* Events used by nodes to communicate with other nodes in the network */
// event: stabilize node, querying their successor's predecessor
event eStabilize;
// event: notify node that it needs to update its predecessor
event eNotify;
// event: initally called when a node needs to know it's succesor
event eSuccesor: Node;
// event: called when a node needs to know a node's predecessor
event ePredecessor: Node;

// Do we want virtual nodes? To do this, we could just assign
// a set of nodes to a server ... maybe?

machine Node {
    var nodeId: int;
    // Number of nodes in Chord
    var N: int;
    // Number of nodes in fingerTable (2^M = N)
    var M: int;
    // Next r successors for fault-tolerance
    var succesorList: seq[Node];
    // Efficient look-up table for finding ids in O(logN)
    var fingerTable: map[int, Node];
    // Preceeding node for this node
    var predecessor: Node;
    // key-value pairs
    var key2map: map[int, int];

    start state Join {
        entry (n; int, m: int, node: Node) {
            N = n;
            M = m;
            send node, eSuccesor, this;
            receive {
                case eSuccesor: (node: Node) {
                    predecessor = node;
                }
            }
            goto WaitForRequests;
        }
    }

    state WaitForRequests {
        // Randomly chosen to check if node is in ideal state
        on eStabilize do {
            var newSuccesor: Node;
            send succesor, ePredecessor, this;
            receive {
                case ePredecessor: (node: Node) {
                    newSuccesor = node;
                }
            }
            if(newSuccesor.id < succesor.id) {
                succesor = newSuccesor;
            }
            send succesor, eNotify, this;
        }

        // Possibly have new predecessor
        on eNotify do (node: Node) {
            if(predecessor == default(machine) || (predecessor.id < nodeId && node.id < nodeId)) {
                predecessor = node;
            }
        }

        // We are currently the head node in the Chord, new node is
        // joining the network and needs to find its successor
        on eSuccesor do (node: Node) {
            send node, eSuccesor, FindSucessor(node.id);
        }

        // Someone wants to know our predecessor
        on ePredecessor do (node: Node) {
            send node, ePredecessor, predecessor;
        }

        // Randomly chosen to shutdown node to simulate failure.
        // Node will be destroyed (instance of P machine is destroyed)
        on eShutDown do {
            raise halt;
        }
    }

    state Leave {
        entry{
            
        }
    }

    fun FindSucessor(id: int)
    {
        var succesor: Node;
        // Grab immmediate successor for the key id
        succesor = succesorList[0];
        // If id isn't tracked by our succesor, then
        // find the predecessor for id in our fingertable
        if(id <= succesor.id) {
            return succesor;
        } else {
            succesor = ClosestPrecedingNode(id);
            return succesor;
        }
    }

    fun ClosestPrecedingNode(id: int)
    {
        var i: int;
        i = M;
        while (i > id - 1) {
            if(if i in fingerTable && fingerTable[i].id < id) {
                return fingerTable[id];
            }
        }
        // return default(machine);
    }
}