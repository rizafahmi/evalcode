const KanbanBoard = {
  mounted() {
    let draggedDealId = null;
    let isDragging = false;

    // Drag start on deal cards
    this.handleDragStart = (e) => {
      const card = e.target.closest(".deal-card[data-deal-id]");
      if (!card) return;

      draggedDealId = card.getAttribute("data-deal-id");
      isDragging = true;
      e.dataTransfer.setData("text/plain", draggedDealId);
      e.dataTransfer.effectAllowed = "move";
      card.classList.add("opacity-40", "scale-[0.98]");
    };

    // Drag end cleanup
    this.handleDragEnd = (e) => {
      const card = e.target.closest(".deal-card[data-deal-id]");
      if (card) {
        card.classList.remove("opacity-40", "scale-[0.98]");
      }
      this.el.querySelectorAll(".kanban-column").forEach((col) => {
        col.classList.remove("ring-1", "ring-signal-green/40", "bg-obsidian/70");
      });
      draggedDealId = null;
      setTimeout(() => {
        isDragging = false;
      }, 100);
    };

    // Prevent accidental link navigation when dragging ends
    this.handleClick = (e) => {
      if (isDragging) {
        e.preventDefault();
        e.stopImmediatePropagation();
      }
    };

    // Drag over column
    this.handleDragOver = (e) => {
      const column = e.target.closest(".kanban-column[data-column-id]");
      if (column) {
        e.preventDefault();
        e.dataTransfer.dropEffect = "move";
      }
    };

    // Drag enter column
    this.handleDragEnter = (e) => {
      const column = e.target.closest(".kanban-column[data-column-id]");
      if (column) {
        e.preventDefault();
        column.classList.add("ring-1", "ring-signal-green/40", "bg-obsidian/70");
      }
    };

    // Drag leave column
    this.handleDragLeave = (e) => {
      const column = e.target.closest(".kanban-column[data-column-id]");
      if (column && !column.contains(e.relatedTarget)) {
        column.classList.remove("ring-1", "ring-signal-green/40", "bg-obsidian/70");
      }
    };

    // Drop on column
    this.handleDrop = (e) => {
      const column = e.target.closest(".kanban-column[data-column-id]");
      if (!column) return;

      e.preventDefault();
      column.classList.remove("ring-1", "ring-signal-green/40", "bg-obsidian/70");

      const dealId = e.dataTransfer.getData("text/plain") || draggedDealId;
      const columnId = column.getAttribute("data-column-id");

      if (dealId && columnId) {
        this.pushEvent("move_deal", {deal_id: dealId, column_id: columnId});
      }
    };

    this.el.addEventListener("dragstart", this.handleDragStart);
    this.el.addEventListener("dragend", this.handleDragEnd);
    this.el.addEventListener("click", this.handleClick, true);
    this.el.addEventListener("dragover", this.handleDragOver);
    this.el.addEventListener("dragenter", this.handleDragEnter);
    this.el.addEventListener("dragleave", this.handleDragLeave);
    this.el.addEventListener("drop", this.handleDrop);
  },

  destroyed() {
    if (this.handleDragStart) this.el.removeEventListener("dragstart", this.handleDragStart);
    if (this.handleDragEnd) this.el.removeEventListener("dragend", this.handleDragEnd);
    if (this.handleClick) this.el.removeEventListener("click", this.handleClick, true);
    if (this.handleDragOver) this.el.removeEventListener("dragover", this.handleDragOver);
    if (this.handleDragEnter) this.el.removeEventListener("dragenter", this.handleDragEnter);
    if (this.handleDragLeave) this.el.removeEventListener("dragleave", this.handleDragLeave);
    if (this.handleDrop) this.el.removeEventListener("drop", this.handleDrop);
  }
};

export default KanbanBoard;
