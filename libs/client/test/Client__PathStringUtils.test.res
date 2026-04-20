open Vitest

module PathStringUtils = Client__PathStringUtils

describe("toForwardSlashes", _t => {
  test("replaces Windows backslashes", t => {
    t
    ->expect(PathStringUtils.toForwardSlashes("src\\components\\Hero.vue"))
    ->Expect.toBe("src/components/Hero.vue")
  })

  test("keeps POSIX paths unchanged", t => {
    t
    ->expect(PathStringUtils.toForwardSlashes("/src/components/Hero.vue"))
    ->Expect.toBe("/src/components/Hero.vue")
  })

  test("handles mixed separators", t => {
    t
    ->expect(PathStringUtils.toForwardSlashes("C:\\Users\\dev/src\\views\\Home.vue"))
    ->Expect.toBe("C:/Users/dev/src/views/Home.vue")
  })
})
