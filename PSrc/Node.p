// transaction status
enum tTransStatus {
    SUCCESS,
    ERROR
}
type tNode = (Id: int, node: Node);

// ==================================================================================================
// Creating/Joing nodes
type tNodeConfig = (Id: int, nodes: seq[Node], nodeIds: seq[int]);

event eConfig: tNodeConfig;

// ==================================================================================================
// Client Requests for writing/reading keys
type tTrans = (client: Client, key: int);
// payload type associated with the `eWriteTransResp` event where `transId` is the transaction Id
// and `status` is the return status of the transaction request.
type tWriteTransResp = (status: tTransStatus);
// payload type associated with the `eReadTransReq` event where `client` is the Client machine sending
// the read request and `key` is the key whose value the client wants to read.
// payload type associated with the `eReadTransResp` event where `val` is the value corresponding to
// the `key` in the read request and `status` is the read status (e.g., success or failure)
type tReadTransResp = (Id: int, status: tTransStatus);
type tFindSuccessor = (trans: tTrans, message: event);

event eGetKeyReq: tTrans;
event eGetKeyResp: tReadTransResp;
event eAddKeyReq: tTrans;
event eAddKeyResp: tWriteTransResp;
event eFindSuccessorReq: tFindSuccessor;

// ==================================================================================================
type tSendKeysReq = (node: Node, kys: set[int]);

/* Events used by nodes to communicate with other nodes in the network */
event eSendKeysReq: tSendKeysReq;
event eSendKeysResp;
event eObtainKeysReq: tNode;
event eObtainKeysResp: set[int];

// ==================================================================================================
// event: stabilize node, querying their successor's predecessor
event eStabilize;
event eNotifySuccessor: tNode;
event eFixSuccessorList;
// event:
event eGetPredecessorReq: Node;
event eGetPredecessorResp: tNode;
// event:
event eSuccessorListReq: Node;
event eSuccessorListResp: seq[tNode];

// ==================================================================================================
// event: called when a node wishes to leave the network
event eLeave;
event eNodeUnavailable;

// ==================================================================================================



machine Node {
    var Id: int;
    // Number of nodes in Chord
    var N: int;
    // Next consecutive successors for fault-tolerance
    var successorList: seq[tNode];
    // Size of our successorList
    var R: int;
    // Preceeding node for this node
    var predecessor: tNode;
    // key-value pairs
    var Keys: set[int];

    // tmp variables
    var i: int;
    var successor: tNode;
    var r: int;
    var idx: int;
    var next: int;

    // Needs to be modified to account for creation of a chord w/
    // a single node and a new node joining the network
    start state Init {
        defer eShutDown, eLeave;
        defer eFindSuccessorReq, eAddKeyReq, eGetKeyReq;
        defer eStabilize, eNotifySuccessor, eGetPredecessorReq, eFixSuccessorList, eSuccessorListReq;

        entry (payload: (n: int, r: int)) {
            N = payload.n;
            R = payload.r;
        }

        on eConfig do (metadata: tNodeConfig) {
            // Determine who is our next R successors
            InitializeNodeLinks(metadata);
            // Wait for incoming requests
            goto WaitForRequests;
        }
    }

    state WaitForRequests {

        on eAddKeyReq do (trans: tTrans) {
            /* If we should have the key, then see if it exists and update. Else,
            find someone who should have the ky*/
            if(InBetween(trans.key, predecessor.Id + 1, Id)) {
                Keys += (trans.key);
            }
            else {
                raise eFindSuccessorReq, (trans = trans, message = eAddKeyReq);
            }
        }

        on eGetKeyReq do (trans: tTrans) {
            // If the requested key is within our interval, check if it exists
            if(InBetween(trans.key, predecessor.Id + 1, Id)) {
                if(trans.key in Keys) {
                    send trans.client, eGetKeyResp, (Id = Id, status = SUCCESS);
                } else {
                    send trans.client, eGetKeyResp, (Id = -1, status = ERROR);
                }
            } else {
                raise eFindSuccessorReq, (trans = trans, message = eGetKeyReq);
            }
        }

        on eFindSuccessorReq do (package: tFindSuccessor) {
            // Worst-case Scenario: Node can't serve any request to successor
            // How do we recover ?!
            if(sizeof(successorList) == 0) {
                return;
            }
            successor = successorList[0];
            // Find the next successsor closest to the given id
            if(InBetween(package.trans.key, Id + 1, successor.Id)) {
                send successor.node, package.message, package.trans;
            } else {
                send successor.node, eFindSuccessorReq, (trans = package.trans, message = package.message);
            }
        }

        on eFixSuccessorList do {
            // Remove immediate successor
            // Ping the next successors to see who is live
            i = 0;
            while (i < sizeof(successorList)) {
                i = i + 1;
                successor = successorList[0];
                send successor.node, eSuccessorListReq, this;
                receive {
                    case eSuccessorListResp: (list: seq[tNode]) {
                        if(sizeof(list) == 0) { continue; }
                        successorList = list;
                        successorList -= (sizeof(list) - 1);
                        successorList += (0, successor);
                        break;
                    }
                    case eNodeUnavailable: {
                        successorList -= (0);
                        continue;
                    }
                }
            }

            announce eSuccessorAltered, (Id = Id, successors = successorList);
        }
        
        // Node is requesting our list of successors
        on eSuccessorListReq do (node: Node) { send node, eSuccessorListResp, successorList; }

        // Randomly chosen to check if node is in ideal state
        on eStabilize do {
            // Worst-case: Can't recover :(
            if(sizeof(successorList) == 0) {
                return;
            }
            // Obtain predecessor of our current successor
            send successorList[0].node, eGetPredecessorReq, this;
            goto WaitToStabilize;
        }

        on eGetPredecessorReq do (node: Node) { send node, eGetPredecessorResp, predecessor; }

        // Possibly have new predecessor
        on eNotifySuccessor do (node: tNode) {
            // If our predecessor does not exist (default(machine)) or the node that pingd us has
            // a lesser id than our current predecessor
            if(predecessor.node == default(machine) || InBetween(node.Id, predecessor.Id + 1, Id - 1)) {
                predecessor = node;
            }
        }

        // Randomly chosen to shutdown node to simulate failure.
        // Node will be destroyed (instance of P machine is destroyed)
        on eShutDown goto Unavailable;

        // Pass keys to successor
        on eLeave do { 
            if(sizeof(successorList) > 0) {
                send successorList[0].node, eSendKeysReq, (node = this, kys = Keys);
                goto WaitToLeave;
            } else {
                Keys = default(set[int]);
                announce eSuccessorAltered, (Id = Id, successors = successorList);
                goto Unavailable;
            }
        }
        
        on eSendKeysReq do (package: tSendKeysReq) {
            var key: int;
            foreach(key in package.kys) {
                Keys += (key);
            }
            send package.node, eSendKeysResp;
        }

        on eObtainKeysReq do (node: tNode) {
            var key: int;
            var ret: set[int];
            foreach (key in Keys) {
                if(key <= node.Id) {
                    ret += (key);
                    Keys -= (key);
                }
            }
            send node.node, eObtainKeysResp, ret;
        }

    }

    state WaitToLeave {
        
        on eNodeUnavailable do {
            successorList -= (0);
            if(sizeof(successorList) > 0) {
                send successorList[0].node, eSendKeysReq, (node = this, kys = Keys);
            } else {
                goto Unavailable;
            }
        }

        on eSendKeysResp goto Unavailable;

        exit {
            Keys = default(set[int]);
            announce eSuccessorAltered, (Id = Id, successors = successorList);
        }

    }

    state WaitToStabilize {
        defer eSuccessorListReq;

        on eGetPredecessorResp do (node: tNode) {
            if(sizeof(successorList) == 0) {
                return;
            }
            successor = successorList[0];
            // Verify if a more ideal successor exists
            if(node.node != default(machine) && InBetween(node.Id, Id + 1, successor.Id - 1)) {
                successorList -= (0);
                successorList += (0, node);
            }
            // Ping our new successor to know we exist
            send successorList[0].node, eNotifySuccessor, (Id = Id, node = this);
            goto WaitForRequests;
        }

        on eNodeUnavailable do {
            successorList -= (0);
            goto WaitForRequests;
        }

        exit {
            announce eSuccessorAltered, (Id = Id, successors = successorList);
        }
    }

    state Unavailable {
        ignore eStabilize, eNotifySuccessor, eObtainKeysReq;

        on eSuccessorListReq do (node: Node) { send node, eNodeUnavailable; }
        
        on eGetPredecessorReq do (node: Node) {send node, eNodeUnavailable; }

        on eSendKeysReq do (package: tSendKeysReq) { send package.node, eNodeUnavailable; }
    }

    fun InitializeNodeLinks(metadata: tNodeConfig)
    {
        var tmp: tNode;
        Id = metadata.Id;
        i = 0;
        // Search for Node's index
        while (i < sizeof(metadata.nodeIds)) {
            if(Id == metadata.nodeIds[i]) {
                idx = i;
                break;
            } 
        }

        // Initialize the successorList
        i = 0;
        r = 0;
        next = idx;
        while (i < sizeof(metadata.nodeIds)) {
            next = (next + 1) % sizeof(metadata.nodeIds);
            tmp = (Id = metadata.nodeIds[next], node = metadata.nodes[next]);
            successorList += (r, tmp);
            r = r + 1;
            if(r == R) {
                break;
            }
        }
        // Initialize the predecessor
        i = (idx + sizeof(metadata.nodeIds) - 1) % sizeof(metadata.nodeIds);
        predecessor = (Id = metadata.nodeIds[i], node = metadata.nodes[i]);
    }

    fun InBetween(x: int, i: int, j: int) : bool
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