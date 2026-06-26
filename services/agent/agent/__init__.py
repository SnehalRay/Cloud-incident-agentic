"""Cloud Incident Lab diagnosis agent.

A LangGraph + Claude agent that queries Prometheus over PromQL and diagnoses
whichever distributed-systems fault is currently active in the lab.
"""
