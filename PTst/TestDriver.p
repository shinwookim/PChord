// type that represents the configuration of the system under test
type tChordConfig = (
    numClients: int,
    numNodes: int,
    numInitialNodes: int,
    numTransPerClient: int,
    failures: int
);

// function that creates the two phase commit system along with the machines in its
// environment (test harness)
type tRingConfig = (nodes: seq[Node], nodeIds: seq[int]);

fun SetUpRing(config: tChordConfig) : tRingConfig
{
    var nodes: seq[Node];
    var nodeIds: seq[int];
    var curNode: Node;
    var curId: int;
    var i : int;

    // Create initial nodes
    while (i < config.numInitialNodes) {
        // Choose a random id for node
        curId = ChooseRandomNode(config.numNodes);
        // Don't add an id twice
        if(curId in nodeIds) { continue; }
        curNode = new Node((n = config.numNodes, r = config.failures + 1));
        // Add to existing nodes
        nodes += (i, curNode);
        nodeIds += (i, curId);
        i = i + 1;
    }

    nodeIds = BubbleSort(nodeIds);

    return (nodes = nodes, nodeIds = nodeIds);
}


/*
This machine creates the 3 participants, 1 coordinator, and 1 clients
*/
machine Chord {
    var nodes: seq[Node];
    var nodeIds: seq[int];
    var unavailable: seq[int];
    var i: int;

    start state Init {
        entry (config: tChordConfig) {
            var metadata: tRingConfig;
            var tmp: set[Node];

            metadata = SetUpRing(config);
            nodes = metadata.nodes;
            nodeIds = metadata.nodeIds;

            // create spec
            announce eMonitor_AtomicityInitialize;

            // assign nodes Ids and begin joining
            i = 0;
            while (i < config.numInitialNodes) {
                send nodes[i], eConfig, (Id = nodeIds[i], nodes = nodes, nodeIds = nodeIds);
                i = i + 1;
            }

            // create clients
            i = 0;
            while(i < config.numClients)
            {
                new Client((nodes = nodes, n = config.numTransPerClient, numNodes = config.numNodes));
                i = i + 1;
            }

            // create node failures
            if(config.failures > 0)
            {
                i = 0;
                while (i < sizeof(nodes)) {
                    tmp += (nodes[i]);
                    i = i + 1;
                }
                CreateFailureInjector((nodes = tmp, nFailures = config.failures));
            }

            goto Stabilize;
        }
    }

    state Stabilize {
        entry {
            send choose(nodes), eStabilize;
            goto FixSuccessorList;
        }
    }

    state FixSuccessorList {
        entry {
            send choose(nodes), eFixSuccessorList;
            goto Stabilize;
        }
    }
}

machine SingleClientNoFailure {
    start state Init {
        entry {
            var config: tChordConfig;
            config = (
                numClients = 1, 
                numNodes = 8,
                numInitialNodes = 4,
                numTransPerClient = 5,
                failures = 0);
            new Chord(config);
        }
    }
}

  
fun ChooseRandomNode(uniqieId: int) : int;

fun BubbleSort(arr: seq[int]) : seq[int]
{
    var i: int;
    var j: int;
    var tmp: int;
    var swapped: bool;
    swapped = false;

    while (i < sizeof(arr) - 1) {
        swapped = false;
        while (j < sizeof(arr) - 1) {
            if(arr[j] > arr[j + 1]) {
                tmp = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = tmp;
                swapped = true;
            }
        }
        if(swapped == false) {
            break;
        }
    }

    return arr;
}