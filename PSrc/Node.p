// User Defined Types
type tNodeConfig : (id: int, nodes: seq[Node], nodeIds: seq[int]);

// a transaction consisting of the key, value, and the unique transaction id.
type tTrans = (key: int, val: int, transId: int);
// payload type associated with the `eWriteTransReq` event where `client`: client sending the
// transaction, `trans`: transaction to be committed.
type tWriteTransReq = (client: Client, trans: tTrans);
// payload type associated with the `eWriteTransResp` event where `transId` is the transaction Id
// and `status` is the return status of the transaction request.
type tWriteTransResp = (transId: int, status: tTransStatus);
// payload type associated with the `eReadTransReq` event where `client` is the Client machine sending
// the read request and `key` is the key whose value the client wants to read.
type tReadTransReq = (client: Client, key: int);
// payload type associated with the `eReadTransResp` event where `val` is the value corresponding to
// the `key` in the read request and `status` is the read status (e.g., success or failure)
type tReadTransResp = (key: int, val: int, status: tTransStatus);

// transaction status
enum tTransStatus {
    SUCCESS,
    ERROR,
    TIMEOUT
  }

/* Events used by nodes to communicate with other nodes in the network */
// event:
event eGetKeyReq: tReadTransReq;
event eGetKeyResp: tReadTransResp;
event eSetKeyReq: tWriteTransReq;
event eSetKeyResp: tWriteTransResp;
// event: stabilize node, querying their successor's predecessor
event eStabilize;
event eNotifySuccesor;
// event: initally called when a node needs to know it's succesor
event eFindSuccessorReq: Node;
event eFindSuccessorResp: Node;
// event:
event eGetPredecessorReq: Node;
event eGetPredecessorResp: Node;
// event:
event eSuccessorListReq: Node;
event eSuccessorListResp: Node;
// Events for creating nodes
event eConfig: tNodeConfig;
event eJoin: tNodeConfig;
event eReJoin;
// event: called when a node wishes to leave the network
event eLeave;
event eNodeUnavailable;

// Do we want virtual nodes? To do this, we could just assign
// a set of nodes to a server ... maybe?

machine Node {
    var Id: int;
    // Number of nodes in Chord
    var N: int;
    // Next consecutive successors for fault-tolerance
    var succesorList: seq[Node];
    // Size of our successorList
    var R: int;
    // Efficient look-up table for finding ids in O(logN)
    // var fingerTable: map[int, Node];
    // Preceeding node for this node
    var predecessor: Node;
    // key-value pairs
    var Keys: map[int, int];
    // Timer for timeouts to detect failures
    var timer: Timer;

    // Needs to be modified to account for creation of a chord w/
    // a single node and a new node joining the network
    start state Init {
        defer eShutDown, eFindSuccessorReq, eLeave, eStabilize, eNotify;

        entry (n; int, r: int) {
            N = n;
            R = r;
            timer = CreateTimer(this);
        }

        on eConfig do (metadata: tNodeConfig) {
            // Determine who is our next R successors
            InitializeSuccessorList(metadata);
            // Initialize the predecessor
            var idx: int;
            var i: int;
            while (i < sizeof(metadata.nodeIds)) {
                if(Id == metadata.nodeIds[i]) {
                    idx = i;
                    break;
                }
            }
            i = (idx + sizeof(metadata.nodesIds) - 1) % sizeof(metadata.nodesIds)
            predecessor = nodes[i];
            // Wait for incoming requests
            goto WaitForRequests;
        }

        on eJoin do (metadata: tNodeConfig) {
            // Determine who is our next R successors
            InitializeSuccessorList(metadata);
            // Notify successor that we exist and are their predecessor
            send succesorList[0], eNotifySuccesor, this;
            // Wait for incoming requests
            goto WaitForRequests;
        }
    }

    state WaitForRequests {

        on eSetKeyReq do (wTrans: tWriteTransReq) {
            /* If we should have the key, then see if it exists and update. Else,
            find someone who should have the ky*/
        }

        on eGetKeyReq do (rTrans: tReadTransReq) {
            // If the requested key is within our interval, check if it exists
            if(predecessor != default(machine) && InBetween(rTrans.key, predecessor.Id + 1, Id)) {
                var val: int;
                var code: int;
                if(rTrans.key in Keys) {
                    val = Keys[rTrans.key];
                    code = SUCCESS;
                } else {
                    val = -1;
                    code = ERROR;
                }
                send rTrans.client, eGetKeyResp, (key = rTrans.key, val = val, status = code);
            }
            else {

                send succesor[0], eGetKeyReq, rTrans;
            }
        }

        on eFindSuccessorReq do (node: Node) {
            var successor: Node;

            succesor = succesorList[0];
            // Find the next successsor closest to the given id
            if(InBetween(node.Id, Id + 1, succesor.Id)) {
                send node, eFindSuccessorResp, succesor;
            } else {
                send succesor, eFindSuccessorReq, node;
            }

        }

        // Node is requesting our list of successors
        on eSuccessorListReq do (node: Node) { send node, eSuccessorListResp, succesorList; }

        on eGetPredecessorReq do (node: Node) { send node, eGetPredecessorResp, predecessor; }

        on eFixSuccessorList do {
            // Remove immediate successor
            var i: int;
            var succesor: Node;
            // Ping the next successors to see who is live
            while (i < sizeof(succesorList)) {
                succesor = succesorList[0];
                send succesor, eSuccessorListReq, this;
                receive {
                    case eSuccessorListResp: (list: seq[Node]) {
                        if(sizeof(list) == 0) { continue; }
                        succesorList = list;
                        succesorList -= (sizeof(list) - 1);
                        succesorList += (0, succesor);
                    }
                    case eNodeUnavailable: {
                        succesorList -= (0);
                        continue;
                    }
                }
            }
        }

        // Randomly chosen to check if node is in ideal state
        on eStabilize do {
            var newSuccesor: Node;
            // Obtain predecessor of our current successor
            send succesorList[0], ePredecessorReq, this;
            goto WaitForGetPedecessorResp;
        }

        // Possibly have new predecessor
        on eNotifySuccesor do (node: Node) {
            // If our predecessor does not exist (default(machine)) or the node that pingd us has
            // a lesser id than our current predecessor
            if(predecessor == default(machine) || InBetween(node.nodeId, predecessor.nodeId, nodeId)) {
                predecessor = node;
            }
        }

        // Randomly chosen to shutdown node to simulate failure.
        // Node will be destroyed (instance of P machine is destroyed)
        on eShutDown goto Unavailable;
        on eLeave goto Unavailable; 
    }

    state WaitForGetPedecessorResp {
        defer eSuccessorListReq;

        on eGetPredecessorResp do (node: Node) {
            // TODO: CONSIDER SUCCESSORlIST[0] FAILS 
            // Might need to implement state change to avoid deadlock
            // Verify if a more ideal successor exists
            if(node != default(machine) && InBetween(node.Id, nodeId + 1, succesorList[0].Id - 1)) {
                succesorList -= (0);
                succesorList += (0, node);
            }
            // Ping our new successor to know we exist
            send succesorList[0], eNotifySuccesor, this;
            goto WaitForRequests;
        }

        on eNodeUnavailable do () {
            succesorList -= (0);
            goto WaitForRequests;
        }
    }

    state Unavailable {
        ignore eStabilize,eNotify;

        on eReJoin goto WaitForRequests;

        on eSuccessorListReq do (package: tNode) { send package.node, eNodeUnavailable; }
        
        on eFindSuccessorReq do (package: tNode) { send package.node, eNodeUnavailable; }
    }

    fun InitializeSuccessorList(metadata: tNodeConfig)
    {
        nodeId = metadata.id;
        var i: int;
        var r: int;
        var idx: int;
        var next: int;

        // Search for Node's index
        while (i < sizeof(metadata.nodeIds)) {
            if(nodeId == metadata.nodesIds[i]) {
                idx = i;
                break;
            } 
        }

        // Initialize the successorList
        i = 0;
        next = idx;
        while (i < sizeof(metadata.nodeIds)) {
            next = (next + 1) % N;
            succesorList += (r, metadata.nodes[next]);
            r += 1;
            if(r == R) {
                break;
            }
        }
    }

    fun InBetween(x: int, i: int, j: int)
    {
        if(i <= j) {
            if(i <= x && x <= j) {
                return true;
            }
        } else {
            if(x >= i || x <= j) {
                return true;
            }
        }

        return false;
    }
}