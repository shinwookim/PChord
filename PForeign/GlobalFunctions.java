package psym.model;

import java.util.Random;

import psym.runtime.values.PInt;

public class GlobalFunctions {
    public static PInt ChooseRandomTransaction(PInt uniqueId) {
        Random rand = new Random();
        return new PInt(rand.nextInt(10));
    }
}
