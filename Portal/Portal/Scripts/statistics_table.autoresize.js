(function () {
      window.onresize = function () {
            var clientWidth = document.getElementById("updatedTable").clientWidth; //container
            document.getElementsByClassName("customHeader")[0].style.width = (clientWidth - 250) * 0.8 + "px";
            document.getElementsByClassName("customTable")[0].style.width = (clientWidth - 250) * 0.8 + "px";
            document.getElementById("updatedTable").style.marginLeft = clientWidth * 0.1 + "px";

            document.getElementsByClassName("customTable")[0].style.height = (document.body.clientHeight) * 0.6 + "px";
            document.getElementsByClassName("firstColumn")[0].style.height = (document.body.clientHeight) * 0.6 + "px";
        };
}());