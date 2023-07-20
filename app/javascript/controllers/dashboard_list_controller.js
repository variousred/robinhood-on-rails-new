import { Controller } from "@hotwired/stimulus";
import FundamentalsTooltip from "fundamentals_tooltip";
import SortableTables from "sortable_table";
import HideOnClick from "hide_on_click";
import PreventDeferredLoader from "prevent_deferred_loader";

export default class extends Controller {

    connect() {
        FundamentalsTooltip(this.element)
        SortableTables(this.element)
        HideOnClick(this.element)
        PreventDeferredLoader(this.element)
    }

    disconnect() {
    }
}