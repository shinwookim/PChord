test tcSingleClientNoFailure [main = SingleClientNoFailure]:
assert AtLeastOneRing, AtMostOneRing, OrderedRing in 
    (union ChordModule, ChordClient, FailureInjector, { SingleClientNoFailure });

test tcTwoClientNoFailure [main = TwoClientNoFailure]:
assert AtLeastOneRing, AtMostOneRing, OrderedRing in
    (union ChordModule, ChordClient, FailureInjector, { TwoClientNoFailure });

test tcSingleClientFailure [main = SingleClientFailure]:
assert AtLeastOneRing, AtMostOneRing, OrderedRing in
    (union ChordModule, ChordClient, FailureInjector, { SingleClientFailure });