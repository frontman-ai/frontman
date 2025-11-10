/* NOTE @Roland
 * - To not break existing code, this is broken out to a V2. Essentially the
 * main difference is that a dispatch directly awaits the result to the state,
 * and returns the state. I noticed a lot of dispatch(); getState(); - and there
 * is actually no technical reason not to directly return the updated state.
 * - This also removes the need for 'waitForNextUpdate' as that's already
 * handled after dispatching.

 * Example Test:
 * ```
 *  testPromise("Initializing 'CreateNew' should create empty DemoCenter", async () => {
 *    let {dispatch} = StateReducerTestingV2.useReducer(module(State), emptyState)
 *    let next = await dispatch(Initialize(State.CreateNew))
 *    let nextDemoCenterId = (next.demoCenter->AsyncData.getComplete->Option.getOrThrow->Result.getOrThrow).id
 *    expect(next)->Expect.toEqual({
 *      ...emptyState,
 *      demoCenter: AsyncData.Complete(Ok({...emptyDemoCenter, id: nextDemoCenterId})),
 *    })
 *  })
 * ```
 */
%%raw(`/* eslint-disable */`)
open StateReducer

module ReactTestingLibrary = Bindings__ReactTestingLibrary
type t<'state, 'action> = {
  getState: unit => 'state,
  dispatch: 'action => promise<'state>,
}

let useReducer:
  type state action effect. (
    module(Interface with type state = state and type action = action and type effect = effect),
    state,
  ) => t<state, action> =

  /* NOTE @Roland - The settimeout below unifies behaviour between sync
      and non-sync updates, pushing the updates to always run in the event
      loop's next frame.
 */
  (module(State), initialValue) => {
    let {result} = ReactTestingLibrary.renderHook(() =>
      StateReducer.useReducer(module(State), initialValue)
    )

    let dispatch = action => {
      let dispatch = Pair.second(result.current)

      ReactTestingLibrary.act(() => {
        setTimeout(() => {
          dispatch(action)
        }, 1)->ignore
      })

      ReactTestingLibrary.waitFor(() => {
        Pair.first(result.current)
      })
    }

    {getState: () => Pair.first(result.current), dispatch}
  }
