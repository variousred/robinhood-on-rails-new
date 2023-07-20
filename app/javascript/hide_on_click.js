export default function HideOnClick(element) {
  $(".hide-on-click").click(function(event) {
    $($(event.target).data("target")).hide()
  })
}