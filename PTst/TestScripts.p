test tcSingleClientNoFailure [main = SingleClientNoFailure]:
    union ChordModule, ChordClient, FailureInjector, { SingleClientNoFailure };