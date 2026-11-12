defmodule FrontmanServerWeb.ConnectionAccessComponents do
  use FrontmanServerWeb, :html

  attr :status, :string, required: true
  attr :retry_path, :string, required: true
  attr :sites, :list, default: []
  attr :restart_required, :boolean, default: false
  attr :switch_account, :boolean, default: true
  attr :assistant_name, :string, default: "ChatGPT"
  attr :retry_label, :string, default: "Check status again"
  slot :retry

  def instructions(assigns) do
    ~H"""
    <div id="subscription-instructions" class="space-y-5">
      <div class="space-y-3">
        <h2 class="font-headings text-xl font-semibold">
          An active subscription or eligible trial is required
        </h2>
        <p id="subscription-reason" class="text-sm leading-6 text-base-content/80">
          {reason(@status)}
        </p>
      </div>

      <.site_links sites={@sites} />
      <.next_steps
        status={@status}
        direct_link={@sites != []}
        switch_account={@switch_account}
        retry_label={@retry_label}
      />

      <p :if={@restart_required} class="text-sm leading-6 text-base-content/70">
        This connection request expires after 15 minutes. If it expires, restart the Frontman connection from your original {@assistant_name} conversation.
      </p>

      <div class="space-y-2 text-sm leading-6">
        <.link
          :if={@switch_account}
          id="use-another-account"
          href={~p"/users/log-out?#{%{return_to: "/wordpress/connect"}}"}
          class="font-semibold text-primary-100 underline underline-offset-4"
        >
          Sign out and use another account
        </.link>
        <p :if={@restart_required && @switch_account} class="text-base-content/70">
          Signing out ends this connection attempt. After signing in with the other account, restart the connection in ChatGPT.
        </p>
        <p class="text-base-content/70">
          Need account assistance? <a
            href="mailto:support@frontman.sh"
            class="font-semibold text-primary-100 underline underline-offset-4"
          >
            Contact Frontman support
          </a>.
          Do not send passwords or card details.
        </p>
      </div>

      <div class="space-y-3">
        <a
          :if={@retry == []}
          id="check-status-again"
          href={@retry_path}
          class={
            if @sites == [],
              do: "btn btn-secondary",
              else: "text-sm font-semibold text-primary-100 underline underline-offset-4"
          }
        >
          {@retry_label}
        </a>
        {render_slot(@retry)}
        <p class="text-sm leading-6 text-base-content/70">
          <strong>{@retry_label}</strong> only checks your account status.
          It does not start a subscription or retry a payment.
          No site has been changed.
        </p>
      </div>
    </div>
    """
  end

  attr :sites, :list, required: true

  defp site_links(assigns) do
    ~H"""
    <div :if={@sites != []} id="frontman-site-links" class="space-y-3">
      <p :if={length(@sites) > 1} class="text-sm leading-6 text-base-content/80">
        Choose the WordPress site you want to open.
      </p>
      <ul class="space-y-3">
        <li :for={site <- @sites}>
          <a
            href={site.url}
            target="_blank"
            rel="noopener noreferrer"
            referrerpolicy="no-referrer"
            class={
              if length(@sites) == 1,
                do: "btn btn-secondary h-auto max-w-full py-3",
                else:
                  "block rounded-xl border border-border p-4 text-sm font-semibold text-primary-100 hover:bg-base-100"
            }
          >
            <span class="min-w-0 leading-6 [overflow-wrap:anywhere]">
              Open Frontman on {site.label}
            </span>
            <.icon name="hero-arrow-top-right-on-square" class="size-4 shrink-0" />
            <span
              :if={length(@sites) > 1}
              class="mt-1 block break-all text-xs font-normal text-base-content/70"
            >
              {site.url}
            </span>
          </a>
        </li>
      </ul>
      <p class="text-sm leading-6 text-base-content/70">
        Opens in a new tab. Sign in to WordPress if asked.
      </p>
    </div>
    """
  end

  attr :status, :string, required: true
  attr :direct_link, :boolean, required: true
  attr :switch_account, :boolean, required: true
  attr :retry_label, :string, required: true

  defp next_steps(assigns) do
    ~H"""
    <div class="space-y-3">
      <h3 class="font-headings font-semibold">What to do next</h3>
      <ol
        id="subscription-next-steps"
        class="list-decimal space-y-3 pl-5 text-sm leading-6 text-base-content/80"
      >
        <li>
          Check the Frontman email shown on this page. Use the account with your existing active subscription or eligible trial.
        </li>
        <%= if @status == "none" do %>
          <li>
            If you already pay for Frontman with another account,
            <%= if @switch_account do %>
              use the sign-out link below.
            <% else %>
              select <strong>Use a different account</strong> above.
            <% end %>
          </li>
          <li>
            If you do not have an active subscription or eligible trial, this connection is not available.
            Contact Frontman support for account assistance.
          </li>
        <% else %>
          <li>
            <%= if @direct_link do %>
              Open Frontman using the site link above. Then open <strong>Settings → Billing</strong>
              to review this account.
            <% else %>
              Open <strong>WordPress Dashboard → Frontman → Settings → Billing</strong>
              to review this account.
            <% end %>
            You do not need an AI provider key to view Billing.
          </li>
          <li>{billing_step(@status)}</li>
          <li>
            After your subscription or trial becomes eligible, return here and select <strong>{@retry_label}</strong>.
          </li>
        <% end %>
      </ol>
    </div>
    """
  end

  defp reason("trialing"),
    do: "Your trial is canceled or otherwise ineligible for assistant access."

  defp reason("past_due"),
    do:
      "Your subscription payment failed. The connection stays blocked until your subscription is active again."

  defp reason("unpaid"),
    do:
      "Your subscription has an unpaid invoice. The connection stays blocked until your subscription is active again."

  defp reason("canceled"),
    do: "Your subscription has ended. This account cannot connect an AI assistant."

  defp reason("paused"),
    do: "Your subscription is paused. The connection is unavailable while it is paused."

  defp reason(status) when status in ["incomplete", "incomplete_expired"],
    do: "Billing setup did not produce an active subscription for this account."

  defp reason("none"), do: "No active subscription is linked to this Frontman account."
  defp reason(_status), do: "Frontman cannot confirm an active subscription for this account."

  defp billing_step(status) when status in ["past_due", "unpaid"],
    do:
      "Select Manage in Stripe. Review your invoice and payment method to resolve the payment issue."

  defp billing_step("trialing"),
    do:
      "Review your trial status in Billing. Contact Frontman support if the status is incorrect."

  defp billing_step(status) when status in ["incomplete", "incomplete_expired"],
    do:
      "If you recently finished billing setup, check its status again. Contact support if it stays inactive."

  defp billing_step(_status),
    do:
      "Review the subscription status in Billing. Contact Frontman support if the status is incorrect."
end
