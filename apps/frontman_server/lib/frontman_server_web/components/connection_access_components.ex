defmodule FrontmanServerWeb.ConnectionAccessComponents do
  use FrontmanServerWeb, :html

  attr :status, :string, required: true
  slot :retry, required: true

  def instructions(assigns) do
    ~H"""
    <div id="subscription-instructions" class="space-y-6">
      <div>
        <p class="inline-flex items-center gap-2 text-[10px] uppercase tracking-[0.16em] text-[#dfc097] before:size-1.5 before:rounded-full before:bg-current">
          Action needed
        </p>
        <h2 class="mt-4 text-3xl font-medium leading-tight tracking-tight">{heading(@status)}</h2>
        <p id="subscription-reason" class="mt-3 text-sm leading-6 text-base-content/65">
          {reason(@status)}
        </p>
      </div>
      <div id="subscription-next-steps" class="space-y-3 text-sm leading-6 text-base-content/75">
        <%= if @status == "none" do %>
          <p>
            Have an existing active subscription on another account?
            Select <strong class="font-medium text-base-content">Use a different account</strong>
            above.
          </p>
          <p>An active subscription or eligible trial is required to connect your assistant.</p>
        <% else %>
          <p class="text-xs uppercase tracking-[0.14em] text-base-content/45">Resolve in Frontman</p>
          <p class="font-medium text-base-content">
            WordPress Dashboard → Frontman → Settings → Billing
          </p>
          <p>{billing_step(@status)}</p>
          <p>Then return here to check access again.</p>
        <% end %>
      </div>
      <div class="space-y-3">
        {render_slot(@retry)}
        <p class="text-xs leading-5 text-base-content/45">
          This only checks access. It does not start a subscription or retry a payment.
          No site has been changed.
        </p>
      </div>
      <details>
        <summary class="cursor-pointer py-2 text-sm text-white/60">
          Need help with this account?
        </summary>
        <div class="space-y-2 pt-3 text-sm leading-6 text-base-content/65">
          <p>
            Check that you are using the account with your existing active subscription or eligible trial.
            You do not need an AI provider key to view Billing.
          </p>
          <p>
            <a
              href="mailto:support@frontman.sh"
              class="text-sm text-primary-200 underline-offset-4 transition-colors duration-250 ease-[cubic-bezier(0.32,0.72,0,1)] hover:text-white hover:underline motion-reduce:transition-none"
            >Contact Frontman support</a>
            for account assistance. Do not send passwords or card details.
          </p>
        </div>
      </details>
    </div>
    """
  end

  defp heading(status) when status in ["past_due", "unpaid"], do: "Update your payment to connect"
  defp heading("none"), do: "This account needs a subscription"
  defp heading("trialing"), do: "Review your trial to connect"
  defp heading(_status), do: "Review your subscription to connect"

  defp reason("trialing"),
    do: "Your trial is canceled or otherwise ineligible for assistant access."

  defp reason("past_due"),
    do: "Your subscription payment failed. Resolve it in Billing to continue."

  defp reason("unpaid"),
    do: "Your subscription has an unpaid invoice. Resolve it in Billing to continue."

  defp reason("canceled"),
    do: "Your subscription has ended. An active subscription or eligible trial is required."

  defp reason("paused"),
    do: "Your subscription is paused. Resume it before connecting your assistant."

  defp reason(status) when status in ["incomplete", "incomplete_expired"],
    do: "Billing setup did not produce an active subscription for this account."

  defp reason("none"), do: "No active subscription is linked to this Frontman account."
  defp reason(_status), do: "Frontman cannot confirm an active subscription for this account."

  defp billing_step(status) when status in ["past_due", "unpaid"],
    do: "Select Manage in Stripe to review your invoice and payment method."

  defp billing_step("trialing"),
    do: "Review your trial status. Contact support if it looks incorrect."

  defp billing_step(status) when status in ["incomplete", "incomplete_expired"],
    do: "Check whether billing setup has completed. Contact support if it stays inactive."

  defp billing_step(_status),
    do: "Review your subscription status. Contact support if it looks incorrect."
end
