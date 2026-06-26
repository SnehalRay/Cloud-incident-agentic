"""Builds the LangGraph diagnosis agent and runs a single diagnosis."""

from __future__ import annotations

from langchain_ollama import ChatOllama
from langgraph.prebuilt import create_react_agent

from . import config
from .prompt import SYSTEM_PROMPT
from .tools import TOOLS

DEFAULT_QUESTION = (
    "Something may be wrong with the lab right now. Investigate the Prometheus "
    "metrics, isolate the single root cause, and prove the closest alternative "
    "is not it."
)


def build_agent():
    """Construct the ReAct-style tool-calling agent backed by a local model."""
    model = ChatOllama(
        model=config.MODEL,
        base_url=config.OLLAMA_BASE_URL,
        temperature=config.TEMPERATURE,
    )
    return create_react_agent(model, TOOLS, prompt=SYSTEM_PROMPT)


def diagnose(question: str = DEFAULT_QUESTION, *, stream: bool = True) -> str:
    """Run one diagnosis. When `stream` is true, print each step as it happens.

    Returns the agent's final text answer.
    """
    agent = build_agent()
    inputs = {"messages": [("user", question)]}
    cfg = {"recursion_limit": config.MAX_ITERATIONS}

    last_ai_text = ""
    if stream:
        for step in agent.stream(inputs, cfg, stream_mode="values"):
            msg = step["messages"][-1]
            _print_step(msg)
            if getattr(msg, "type", None) == "ai" and isinstance(msg.content, str):
                last_ai_text = msg.content or last_ai_text
    else:
        result = agent.invoke(inputs, cfg)
        last_ai_text = result["messages"][-1].content

    return last_ai_text


def _print_step(msg) -> None:
    """Render one message from the stream to stdout for live visibility."""
    mtype = getattr(msg, "type", "")
    if mtype == "ai":
        for call in getattr(msg, "tool_calls", []) or []:
            print(f"\n  -> {call['name']}({call['args']})")
        if isinstance(msg.content, str) and msg.content.strip():
            print(f"\n{msg.content}")
    elif mtype == "tool":
        content = msg.content if isinstance(msg.content, str) else str(msg.content)
        snippet = content if len(content) <= 600 else content[:600] + " …"
        print(f"     {snippet}")
