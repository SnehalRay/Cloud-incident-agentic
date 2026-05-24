package com.example.backend_spring.config;

public class ShardContext {

    private static final ThreadLocal<Integer> current = new ThreadLocal<>();

    public static void set(int shard) { current.set(shard); }

    public static Integer get() { return current.get(); }

    public static void clear() { current.remove(); }
}
