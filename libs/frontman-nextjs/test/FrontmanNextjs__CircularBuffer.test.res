open Vitest

module CircularBuffer = FrontmanNextjs__CircularBuffer

describe("CircularBuffer", _t => {
  describe("Basic Operations", _t => {
    test(
      "make creates empty buffer with correct capacity",
      t => {
        let buffer = CircularBuffer.make(~capacity=10)
        t->expect(CircularBuffer.length(buffer))->Expect.toBe(0)
      },
    )

    test(
      "length returns 0 for new buffer",
      t => {
        let buffer = CircularBuffer.make(~capacity=5)
        t->expect(CircularBuffer.length(buffer))->Expect.toBe(0)
      },
    )

    test(
      "toArray returns empty array for new buffer",
      t => {
        let buffer = CircularBuffer.make(~capacity=5)
        t->expect(CircularBuffer.toArray(buffer))->Expect.toEqual([])
      },
    )
  })

  describe("Push and Capacity", _t => {
    test(
      "push single item increases length to 1",
      t => {
        let buffer = CircularBuffer.make(~capacity=10)
        let buffer = CircularBuffer.push(buffer, "a")
        t->expect(CircularBuffer.length(buffer))->Expect.toBe(1)
        t->expect(CircularBuffer.toArray(buffer))->Expect.toEqual(["a"])
      },
    )

    test(
      "push N items (N < capacity) returns all in order",
      t => {
        let buffer = CircularBuffer.make(~capacity=10)
        let buffer = CircularBuffer.push(buffer, "a")
        let buffer = CircularBuffer.push(buffer, "b")
        let buffer = CircularBuffer.push(buffer, "c")

        t->expect(CircularBuffer.length(buffer))->Expect.toBe(3)
        t->expect(CircularBuffer.toArray(buffer))->Expect.toEqual(["a", "b", "c"])
      },
    )

    test(
      "push exactly capacity items returns all items",
      t => {
        let buffer = CircularBuffer.make(~capacity=3)
        let buffer = CircularBuffer.push(buffer, "a")
        let buffer = CircularBuffer.push(buffer, "b")
        let buffer = CircularBuffer.push(buffer, "c")

        t->expect(CircularBuffer.length(buffer))->Expect.toBe(3)
        t->expect(CircularBuffer.toArray(buffer))->Expect.toEqual(["a", "b", "c"])
      },
    )

    test(
      "push capacity + 1 items evicts oldest",
      t => {
        let buffer = CircularBuffer.make(~capacity=3)
        let buffer = CircularBuffer.push(buffer, "a")
        let buffer = CircularBuffer.push(buffer, "b")
        let buffer = CircularBuffer.push(buffer, "c")
        let buffer = CircularBuffer.push(buffer, "d")

        t->expect(CircularBuffer.length(buffer))->Expect.toBe(3)
        t->expect(CircularBuffer.toArray(buffer))->Expect.toEqual(["b", "c", "d"])
      },
    )

    test(
      "push 2x capacity items keeps only last capacity items",
      t => {
        let buffer = CircularBuffer.make(~capacity=3)
        let buffer = CircularBuffer.push(buffer, "a")
        let buffer = CircularBuffer.push(buffer, "b")
        let buffer = CircularBuffer.push(buffer, "c")
        let buffer = CircularBuffer.push(buffer, "d")
        let buffer = CircularBuffer.push(buffer, "e")
        let buffer = CircularBuffer.push(buffer, "f")

        t->expect(CircularBuffer.length(buffer))->Expect.toBe(3)
        t->expect(CircularBuffer.toArray(buffer))->Expect.toEqual(["d", "e", "f"])
      },
    )
  })

  describe("Chronological Ordering", _t => {
    test(
      "items not wrapped return in insertion order",
      t => {
        let buffer = CircularBuffer.make(~capacity=10)
        let buffer = CircularBuffer.push(buffer, 1)
        let buffer = CircularBuffer.push(buffer, 2)
        let buffer = CircularBuffer.push(buffer, 3)
        let buffer = CircularBuffer.push(buffer, 4)

        t->expect(CircularBuffer.toArray(buffer))->Expect.toEqual([1, 2, 3, 4])
      },
    )

    test(
      "items wrapped once return in correct chronological order",
      t => {
        let buffer = CircularBuffer.make(~capacity=3)
        let buffer = CircularBuffer.push(buffer, "a")
        let buffer = CircularBuffer.push(buffer, "b")
        let buffer = CircularBuffer.push(buffer, "c")
        let buffer = CircularBuffer.push(buffer, "d")
        let buffer = CircularBuffer.push(buffer, "e")

        t->expect(CircularBuffer.toArray(buffer))->Expect.toEqual(["c", "d", "e"])
      },
    )

    test(
      "items wrapped multiple times maintain order",
      t => {
        let buffer = CircularBuffer.make(~capacity=3)

        // Wrap multiple times
        let buffer = CircularBuffer.push(buffer, "a")
        let buffer = CircularBuffer.push(buffer, "b")
        let buffer = CircularBuffer.push(buffer, "c")
        let buffer = CircularBuffer.push(buffer, "d")
        let buffer = CircularBuffer.push(buffer, "e")
        let buffer = CircularBuffer.push(buffer, "f")
        let buffer = CircularBuffer.push(buffer, "g")
        let buffer = CircularBuffer.push(buffer, "h")

        t->expect(CircularBuffer.toArray(buffer))->Expect.toEqual(["f", "g", "h"])
      },
    )
  })

  describe("Edge Cases", _t => {
    test(
      "capacity 1 buffer keeps only most recent item",
      t => {
        let buffer = CircularBuffer.make(~capacity=1)
        let buffer = CircularBuffer.push(buffer, "a")
        let buffer = CircularBuffer.push(buffer, "b")
        let buffer = CircularBuffer.push(buffer, "c")

        t->expect(CircularBuffer.length(buffer))->Expect.toBe(1)
        t->expect(CircularBuffer.toArray(buffer))->Expect.toEqual(["c"])
      },
    )

    test(
      "clear buffer resets to empty state",
      t => {
        let buffer = CircularBuffer.make(~capacity=5)
        let buffer = CircularBuffer.push(buffer, "a")
        let buffer = CircularBuffer.push(buffer, "b")
        let buffer = CircularBuffer.push(buffer, "c")

        let buffer = CircularBuffer.clear(buffer)

        t->expect(CircularBuffer.length(buffer))->Expect.toBe(0)
        t->expect(CircularBuffer.toArray(buffer))->Expect.toEqual([])
      },
    )

    test(
      "push after clear works correctly",
      t => {
        let buffer = CircularBuffer.make(~capacity=3)
        let buffer = CircularBuffer.push(buffer, "a")
        let buffer = CircularBuffer.push(buffer, "b")
        let buffer = CircularBuffer.clear(buffer)
        let buffer = CircularBuffer.push(buffer, "x")
        let buffer = CircularBuffer.push(buffer, "y")

        t->expect(CircularBuffer.length(buffer))->Expect.toBe(2)
        t->expect(CircularBuffer.toArray(buffer))->Expect.toEqual(["x", "y"])
      },
    )

    test(
      "very large capacity works without issues",
      t => {
        let buffer = CircularBuffer.make(~capacity=10000)

        // Push 100 items
        let buffer = ref(buffer)
        for i in 0 to 99 {
          buffer := CircularBuffer.push(buffer.contents, i)
        }

        t->expect(CircularBuffer.length(buffer.contents))->Expect.toBe(100)
      },
    )
  })

  describe("Immutability", _t => {
    test(
      "push returns new buffer state",
      t => {
        let buffer1 = CircularBuffer.make(~capacity=5)
        let buffer2 = CircularBuffer.push(buffer1, "a")
        let buffer3 = CircularBuffer.push(buffer2, "b")

        // Each push returns a new state
        t->expect(CircularBuffer.length(buffer1))->Expect.toBe(0)
        t->expect(CircularBuffer.length(buffer2))->Expect.toBe(1)
        t->expect(CircularBuffer.length(buffer3))->Expect.toBe(2)
      },
    )

    test(
      "multiple pushes create proper state progression",
      t => {
        let buffer = CircularBuffer.make(~capacity=5)

        let states = [
          CircularBuffer.push(buffer, 1),
          CircularBuffer.push(CircularBuffer.push(buffer, 1), 2),
          CircularBuffer.push(CircularBuffer.push(CircularBuffer.push(buffer, 1), 2), 3),
        ]

        t->expect(CircularBuffer.length(states[0]->Option.getOrThrow))->Expect.toBe(1)
        t->expect(CircularBuffer.length(states[1]->Option.getOrThrow))->Expect.toBe(2)
        t->expect(CircularBuffer.length(states[2]->Option.getOrThrow))->Expect.toBe(3)
      },
    )
  })
})
