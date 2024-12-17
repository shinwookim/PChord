test tcSingleClientNoFailure [main = SingleClientNoFailure]:
assert AtLeastOneRing, OrderedRing in 
    (union ChordModule, ChordClient, FailureInjector, { SingleClientNoFailure });

test tcTwoClientNoFailure [main = TwoClientNoFailure]:
assert AtLeastOneRing, OrderedRing in
    (union ChordModule, ChordClient, FailureInjector, { TwoClientNoFailure });

test tcSingleClientFailure [main = SingleClientFailure]:
assert AtLeastOneRing, OrderedRing in
    (union ChordModule, ChordClient, FailureInjector, { SingleClientFailure });