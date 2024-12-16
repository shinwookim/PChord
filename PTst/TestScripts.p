test tcSingleClientNoFailure [main = SingleClientNoFailure]:
assert AtLeastOneRing in 
    (union ChordModule, ChordClient, FailureInjector, { SingleClientNoFailure });

test tcTwoClientNoFailure [main = TwoClientNoFailure]:
assert AtLeastOneRing in
    (union ChordModule, ChordClient, FailureInjector, { TwoClientNoFailure });

test tcSingleClientFailure [main = SingleClientFailure]:
assert AtLeastOneRing in
    (union ChordModule, ChordClient, FailureInjector, { SingleClientFailure });