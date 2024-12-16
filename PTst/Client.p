machine Client {
    var nodes: seq[Node];
    var N: int;
    var numNodes: int;
    
    start state Init {
        entry (payload: (nodes: seq[Node], n: int, numNodes: int)) {
            nodes = payload.nodes;
            N = payload.n;
            numNodes = payload.numNodes;
            goto SendWriteReq;
        }
    }

    state SendWriteReq {
        ignore eGetKeyResp;

        entry {
            send choose(nodes), eAddKeyReq, (client = this, key = ChooseRandomNode(numNodes));
            if(N > 0) {
                N = N - 1;
                goto SendReadReq;
            }
        }
    }

    state SendReadReq {
        ignore eGetKeyResp;

        entry {
            send choose(nodes), eGetKeyReq, (client = this, key = ChooseRandomNode(numNodes));
            if(N > 0) {
                N = N - 1;
                goto SendWriteReq;
            }
        }
    }
}