import { initEditor, schema, splitTaskItem } from "../js/editor";
import { EditorState } from "prosemirror-state";
import { EditorView } from "prosemirror-view";
import { ProsemirrorTestChain } from "jest-prosemirror";
import { builders } from "prosemirror-test-builder";

const { doc, taskList, taskItem, paragraph } = builders(schema);

describe("Editor initialization", () => {
  let container;

  beforeEach(() => {
    container = document.createElement("div");
    document.body.appendChild(container);
  });

  afterEach(() => {
    document.body.removeChild(container);
  });

  test("initializes with empty content", () => {
    let view = initEditor(container);
    expect(view instanceof EditorView).toBeTruthy();
    expect(view.state instanceof EditorState).toBeTruthy();
  });

  test("initializes with provided content", () => {
    container.dataset.content = "<p>Hello world</p>";
    let view = initEditor(container);
    const content = view.state.doc.textContent;
    expect(content).toBe("Hello world");
  });
});

const setupEditor = (content) => {
  const container = document.createElement("div");
  const view = ProsemirrorTestChain.of(initEditor(container));
  if (content) {
    view.overwrite(content);
  }
  document.body.appendChild(container);
  return view;
};

describe("Editor", () => {
  test("creates task list on [] input", () => {
    setupEditor()
      .insertText("[]")
      .callback((content) => {
        expect(content.state.doc).toEqualProsemirrorNode(
          doc(taskList(taskItem(paragraph()))),
        );
      });
  });

  test("splits paragraph on Enter", () => {
    const initialDoc = doc(paragraph("Hello world"));

    setupEditor(initialDoc)
      .press("Enter")
      .callback((content) => {
        expect(content.state.doc).toEqualProsemirrorNode(
          doc(paragraph("Hello world"), paragraph("")),
        );
      });
  });

  test("creates task item on Enter input when in task list", () => {
    const initialDoc = doc(taskList(taskItem(paragraph("test"))));

    setupEditor(initialDoc)
      .press("Enter")
      .callback((content) => {
        expect(content.state.doc).toEqualProsemirrorNode(
          doc(
            taskList(
              taskItem({ "data-done": "false" }, paragraph("test")),
              taskItem({ "data-done": "false" }, paragraph()),
            ),
          ),
        );
      });
  });

  test("removes task list when pressing Enter in a task list with one empty item", () => {
    const initialDoc = doc(
      paragraph("Some preceding text"),
      taskList(taskItem(paragraph(""))),
    );

    setupEditor(initialDoc)
      .press("Enter")
      .callback((content) => {
        expect(content.state.doc).toEqualProsemirrorNode(
          doc(paragraph("Some preceding text"), paragraph()),
        );
      });
  });

  test.each([
    {
      name: "with multiple items and preceding text",
      initialDoc: doc(
        paragraph("Some preceding text"),
        taskList(taskItem(paragraph("Some task")), taskItem(paragraph(""))),
      ),
      expectedDoc: doc(
        paragraph("Some preceding text"),
        taskList(taskItem(paragraph("Some task"))),
        paragraph(),
      ),
    },
    {
      name: "with single empty item and preceding text",
      initialDoc: doc(
        paragraph("Some preceding text"),
        taskList(taskItem(paragraph(""))),
      ),
      expectedDoc: doc(paragraph("Some preceding text"), paragraph()),
    },
    {
      name: "with single empty item and no preceding text",
      initialDoc: doc(taskList(taskItem(paragraph("")))),
      expectedDoc: doc(paragraph()),
    },
  ])(
    "ends task list when pressing Enter ($name)",
    ({ initialDoc, expectedDoc, name }) => {
      setupEditor(initialDoc)
        .press("Enter")
        .callback((content) => {
          expect(content.state.doc).toEqualProsemirrorNode(expectedDoc);
        });
    },
  );
});
