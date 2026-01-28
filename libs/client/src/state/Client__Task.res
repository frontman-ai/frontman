// Task Bounded Context - Public Interface
//
// The Task aggregate manages conversation state including messages,
// streaming, tool calls, and UI state like element selection.

// ============================================================================
// Aggregate Root
// ============================================================================

module Task = Client__Task__Types.Task

// ============================================================================
// Value Objects
// ============================================================================

module Message = Client__Task__Types.Message
module UserContentPart = Client__Task__Types.UserContentPart
module AssistantContentPart = Client__Task__Types.AssistantContentPart
module SelectedElement = Client__Task__Types.SelectedElement
module FigmaNode = Client__Task__Types.FigmaNode
module Todo = Client__Task__Types.Todo

// ============================================================================
// Commands (what you can ask a Task to do)
// ============================================================================

type action = Client__Task__Reducer.action

// ============================================================================
// Query Interface
// ============================================================================

module Selectors = Client__Task__Reducer.Selectors

// ============================================================================
// Reducer
// ============================================================================

let next = Client__Task__Reducer.next
