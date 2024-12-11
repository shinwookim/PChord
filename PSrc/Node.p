// User Defined Types
type tNodeConfig : (id: int, nodes: seq[Node], nodeIds: seq[int]);

// a transaction consisting of the key, value, and the unique transaction id.
type tTransReq = (client: Client, key: int, req: event);
// payload type associated with the `eWriteTransReq` event where `client`: client sending the
// transaction, `trans`: transaction to be committed.
type tWriteTransReq = (client: Client, trans: tTrans);
// payload type associated with the `eWriteTransResp` event where `transId` is the transaction Id
// and `status` is the return status of the transaction request.
type tWriteTransResp = (status: tTransStatus);
// payload type associated with the `eReadTransReq` event where `client` is the Client machine sending
// the read request and `key` is the key whose value the client wants to read.
type tReadTransReq = (client: Client, key: int);
// payload type associated with the `eReadTransResp` event where `val` is the value corresponding to
// the `key` in the read request and `status` is the read status (e.g., success or failure)
type tReadTransResp = (Id: int, status: tTransStatus);

type tSendKeysReq = (node: Node, kys: set[int])

// transaction status
enum tTransStatus {
    SUCCESS,
    ERROR,
}

/* Events used by nodes to communicate with other nodes in the network */
event eGetKeyReq: tReadTransReq;
event eGetKeyResp: tReadTransResp;
event eSetKeyReq: tWriteTransReq;
event eSetKeyResp: tWriteTransResp;

event eSendKeysReq: tSendKeysReq;
event eSendKeysResp;
event eObtainKeysReq: node;
event eObtainKeysResp: set[int];
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
    // Preceeding node for this node
    var predecessor: Node;
    // key-value pairs
    var Keys: set[int];
    // Timer for timeouts to detect failures
    var timer: Timer;

    // Needs to be modified to account for creation of a chord w/
    // a single node and a new node joining the network
    start state Init {
        defer eShutDown, eFindSuccessorReq, eLeave, eStabilize, eNotify;

        entry (n; int, r: int) {
            N = n;
            R = r;
        }

        on eConfig do (metadata: tNodeConfig) {
            // Determine who is our next R successors
            InitializeNodeLinks(metadata);
            // Wait for incoming requests
            goto WaitForRequests;
        }

        on eJoin do (metadata: tNodeConfig) {
            // Determine who is our next R successors
            InitializeNodeLinks(metadata);
            // Nofiy our successor that we are a potential predecessor
            send succesorList[0], eNotifySuccesor, this;
            // Obtain our interval of keys from our successor
            send successorList[0], eObtainKeysReq
        }

        on eObtainKeysResp do (kys: set[int]) {
            // Update our set of keys
            Keys = kys;
            // Wait for incoming requests
            goto WaitForRequests;
        }
    }

    state WaitForRequests {

        on eAddKeyReq do (trans: tTrans) {
            /* If we should have the key, then see if it exists and update. Else,
            find someone who should have the ky*/
            if(InBetween(trans.key, predecessor.Id + 1, Id)) {
                Keys += trans.key;
            }
            else {
                raise eFindSuccessorReq, (trans, eAddKeyReq);
            }
        }

        on eGetKeyReq do (trans: tTrans) {
            // If the requested key is within our interval, check if it exists
            if(InBetween(trans.key, predecessor.Id + 1, Id)) {
                var val: int;
                var code: int;
                if(trans.key in Keys) {
                    val = Id;
                    code = SUCCESS;
                } else {
                    val = -1;
                    code = ERROR;
                }
                send trans.client, eGetKeyResp, (Id = val, status = code);
            }
            else {
                raise eFindSuccessorReq, (trans, eGetKeyReq);
            }
        }

        on eFindSuccessorReq do (trans: tTrans, message: event) {
            var successor: Node;
            succesor = succesorList[0];
            // Find the next successsor closest to the given id
            if(InBetween(node.Id, Id + 1, succesor.Id)) {
                send succesor[0], message, trans;
            } else {
                send succesor[0], eFindSuccessorReq, (trans, message);
            }
        }

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
                        break;
                    }
                    case eNodeUnavailable: {
                        succesorList -= (0);
                        continue;
                    }
                }
            }
        }
        
        // Node is requesting our list of successors
        on eSuccessorListReq do (node: Node) { send node, eSuccessorListResp, succesorList; }

        // Randomly chosen to check if node is in ideal state
        on eStabilize do {
            var newSuccesor: Node;
            // Obtain predecessor of our current successor
            send succesorList[0], eGetPredecessorReq, this;
            goto WaitForResp;
        }

        on eGetPredecessorReq do (node: Node) { send node, eGetPredecessorResp, predecessor; }

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

        // Pass keys to successor
        on eLeave do { 
            if(sizeof(succesorList) > 0) {
                send succesorList[0], eSendKeysReq, (node = this, kys = Keys);
            } else {
                Keys = default(set[int]);
                goto Unavailable;
            }
        }
        
        on eSendKeysReq do (package: tSendKeysReq) {
            var key: int;
            foreach(key in package.kys) {
                Keys += (ky);
            }
            send package.node, eSendKeysResp, SUCCESS;
        }

        on eObtainKeysReq do (node: Node) {
            var key: int;
            var ret: set[int];
            foreach (key in Keys) {
                if(key <= node.Id) {
                    ret += key;
                }
            }
            send node, eObtainKeysResp, ret;
        }

    }

    state WaitToLeave {
        
        on eNodeUnavailable do {
            succesorList -= (0);
            if(sizeof(succesorList) > 0) {
                send succesorList[0], eSendKeysReq, (node = this, kys = Keys);
            } else {
                Keys = default(set[int]);
                goto Unavailable;
            }
        }

        on eSendKeysResp goto Unavailable with {Keys = default(set[int]);}

    }

    state WaitForResp {
        defer eSuccessorListReq;

        on eGetPredecessorResp do (node: Node) {
            // Verify if a more ideal successor exists
            if(node != default(machine) && InBetween(node.Id, nodeId + 1, succesorList[0].Id - 1)) {
                succesorList -= (0);
                succesorList += (0, node);
            }
            // Ping our new successor to know we exist
            send succesorList[0], eNotifySuccesor, this;
            goto WaitForRequests;
        }

        on eNodeUnavailable do {
            succesorList -= (0);
            goto WaitForRequests;
        }
    }

    state Unavailable {
        ignore eStabilize, eNotifySuccesor; eObtainKeysReq;

        on eJoin do (metadata: tNodeConfig) {
            // Determine who is our next R successors
            InitializeNodeLinks(metadata);
            // Notify successor that we exist and are their predecessor
            send succesorList[0], eNotifySuccesor, this;
            // Wait for incoming requests
            goto WaitForRequests;
        }

        on eSuccessorListReq do (package: tNode) { send package.node, eNodeUnavailable; }
        
        on eFindSuccessorReq do (package: tNode) { send package.node, eNodeUnavailable; }
    }

    fun InitializeNodeLinks(metadata: tNodeConfig)
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
        // Initialize the predecessor
        i = (idx + sizeof(metadata.nodesIds) - 1) % sizeof(metadata.nodesIds)
        predecessor = nodes[i];
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