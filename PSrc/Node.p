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
event eSuccesorReq: Node;
event eSuccesorResp: Node;
// event: called when a node needs to know a node's predecessor
event ePredecessorReq: Node;
event ePredecessorResp: Node;
// event: exchange keys
event: eExchangeKeysReq;
event: eExchangeKeysResp;
// event: called when a node wishes to join the network
event eJoin;
// event: called when a node wishes to leave the network
event eLeave;

// Do we want virtual nodes? To do this, we could just assign
// a set of nodes to a server ... maybe?

machine Node {
    var nodeId: int;
    // Number of nodes in Chord
    var N: int;
    // Number of nodes in fingerTable (2^M = N)
    // var M: int;
    // Next consecutive successors for fault-tolerance
    var succesorList: seq[Node];
    // Size of our successorList
    var R: int;
    // Efficient look-up table for finding ids in O(logN)
    // var fingerTable: map[int, Node];
    // Preceeding node for this node
    var predecessor: Node;
    // key-value pairs
    var key2map: map[int, int];

    // Needs to be modified to account for creation of a chord w/
    // a single node and a new node joinging the network
    start state Join {
        entry (n; int, node: Node, r: int) {
            N = n;
            R = r;
            send node, eSuccesorReq, this;
            receive {
                case eSuccesorResp: (node: Node) {
                    succesorList += (0, node);
                }
            }
            goto WaitForRequests;
        }
    }

    state WaitForRequests {

        // Randomly chosen to check if node is in ideal state
        on eStabilize do {
            var newSuccesor: Node;
            // Obtain predecessor of our current successor
            send succesorList[0], ePredecessorReq, this;
            receive {
                case ePredecessorResp: (node: Node) {
                    newSuccesor = node;
                }
            }
            // Verify if a more ideal successor exists
            if(newSuccesor.id < succesor.id) {
                succesorList += (0, newSuccesor);
            }
            // Ping our new successor to know we exist
            send succesor, eNotify, this;
        }

        // Possibly have new predecessor
        on eNotify do (node: Node) {
            // If our predecessor does not exist (default(machine)) or the node that pingd us has
            // a lesser id than our current predecessor
            if(predecessor == default(machine) || (predecessor.id < nodeId && node.id < nodeId)) {
                predecessor = node;
            }
        }

        // Someone wants to know who our successor is
        on eSuccesor do (node: Node) {
            send node, eSuccesor, FindSucessor(node.id);
        }

        // Someone wants to know who our predecessor is
        on ePredecessor do (node: Node) {
            send node, ePredecessor, predecessor;
        }

        // Randomly chosen to shutdown node to simulate failure.
        // Node will be destroyed (instance of P machine is destroyed)
        on eShutDown do {
            raise halt;
        }

        // Node decides to leve the network
        on eLeave goto Leave; 
    }

    // Idel state: does nothing but represent the node has left the network and waits to join the network
    state Leave {
        on eJoin goto WaitForRequests;
    }
    
    fun getId()
    {

    }

    fun exchangeKeys(node: Node, id: int)
    {
        
    }

    fun FindSucessor(id: int)
    {
        var succesor: Node;
        // Grab immmediate successor for the key id
        succesor = succesorList[0];
        // If id isn't tracked by our succesor, then
        // find the predecessor for id in our fingertabl
        
        if(id <= succesor.id) {
            return succesor;
        } else {
            // Send query to next machine
            //succesor = ClosestPrecedingNode(id);
            return succesor;
        }
    }
}