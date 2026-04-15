/**
 * Client__PlanDisplay - Wrapper component for plan display
 * 
 * Uses the new Client__PlanList component for rendering plan entries.
 */
module PlanList = Client__PlanList
module ACPTypes = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

@react.component
let make = (~entries: array<ACPTypes.planEntry>) => {
  <PlanList entries />
}
